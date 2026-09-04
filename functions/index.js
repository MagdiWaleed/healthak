"use strict";

const crypto = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {defineSecret} = require("firebase-functions/params");
const {onRequest} = require("firebase-functions/v2/https");

initializeApp();

const xaiApiKey = defineSecret("XAI_API_KEY");
const maxTurnsPerDay = 30;
const maxCallsPerTurn = 7;

// Server-owned model allowlist. Pair with
// lib/service/agent/agent_model_catalog.dart. The value is the `reasoning_effort`
// to send, or null to omit it (the fast/full Grok models reject the field).
const modelAllowlist = {
  "grok-3-mini": "low",
  "grok-4-fast-non-reasoning": null,
  "grok-4-fast-reasoning": null,
  "grok-4": null,
};
const defaultModel = "grok-3-mini";

// Pair with lib/service/agent/agent_tools.dart and agent_prompt.dart. The proxy
// owns these schemas and the system prompt:
// a modified client may ask for fewer tools, but can never grant the model a
// tool that the server did not approve.
const readTools = [
  tool("get_today", "Read the current day log with entries, eaten state, totals, and targets."),
  tool(
      "get_history_range",
      "Read recent consumed and target nutrition summaries, up to seven days.",
      {
        days: {type: "integer", minimum: 1, maximum: 7},
      },
      ["days"],
  ),
  tool("get_profile", "Read body statistics, activity, goal, and calculated nutrition targets."),
  tool("get_meals", "Read the saved meal library with grounded totals and components."),
  tool(
      "search_foods",
      "Search the real food catalogs. Use before stating food macros.",
      {
        query: {type: "string", minLength: 2, maxLength: 80},
      },
      ["query"],
  ),
  tool("get_remaining_targets", "Calculate kcal and macro grams remaining today."),
];

const systemPrompt = `أنت «المساعد» داخل تطبيق صحتك، مساعد تغذية عربي ودود ودقيق.
استخدم العربية الفصحى المعاصرة حصرًا. افهم اللهجات العامية إن استخدمها المستخدم، لكن أجب دائمًا بالفصحى الواضحة والمختصرة ولا تستخدم لهجة محلية.
استخدم الأدوات لأي معلومة تخص أرقام المستخدم أو طعامه أو وجباته. لا تخمّن أي رقم.
السعرات والعناصر الغذائية الكبرى لا تأتي إلا من نتائج الأدوات، واذكر بوضوح عندما لا تتوفر بيانات.
لا تشخّص أمراضًا ولا تستخدم لغة لوم أو تخويف أو تشجيع لاضطراب الأكل.
هذه المرحلة للقراءة فقط: لا تدّع أنك أضفت أو حذفت أو غيّرت شيئًا.
اجعل الإجابة عملية: قدّم الخلاصة أولًا، ثم أضف تفصيلًا موجزًا عند الحاجة.`;

function tool(name, description, properties = {}, required = []) {
  return {
    type: "function",
    function: {
      name,
      description,
      parameters: {
        type: "object",
        properties,
        required,
        additionalProperties: false,
      },
    },
  };
}

function sendEvent(response, event) {
  response.write(`data: ${JSON.stringify(event)}\n\n`);
}

function fail(response, status, code, messageAr) {
  response.status(status);
  response.set("Content-Type", "application/json; charset=utf-8");
  response.send({code, messageAr});
}

function localDateKey() {
  // Usage limits reset on Riyadh's calendar day, matching the product's home
  // timezone rather than the Cloud Function region.
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Riyadh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

async function consumeQuota(uid, turnId) {
  const db = getFirestore();
  const ref = db.collection("agentUsage").doc(`${uid}_${localDateKey()}`);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const turns = Array.isArray(snapshot.data()?.turns) ? snapshot.data().turns : [];
    const existing = turns.findIndex((turn) => turn.id === turnId);
    if (existing === -1 && turns.length >= maxTurnsPerDay) return false;

    const next = turns.map((turn) => ({id: turn.id, calls: Number(turn.calls) || 0}));
    if (existing === -1) {
      next.push({id: turnId, calls: 1});
    } else {
      if (next[existing].calls >= maxCallsPerTurn) return false;
      next[existing].calls += 1;
    }
    transaction.set(ref, {
      uid,
      dateKey: localDateKey(),
      turns: next,
      updatedAt: new Date(),
    });
    return true;
  });
}

function validMessages(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > 80) return false;
  return value.every((message) => {
    if (!message || typeof message !== "object") return false;
    if (!["user", "assistant", "tool", "system"].includes(message.role)) return false;
    if (typeof message.content === "string" && message.content.length > 12000) return false;
    return true;
  });
}

exports.agentTurn = onRequest(
    {
      region: "us-central1",
      timeoutSeconds: 35,
      memory: "256MiB",
      secrets: [xaiApiKey],
      cors: false,
    },
    async (request, response) => {
      if (request.method !== "POST") {
        fail(response, 405, "method_not_allowed", "هذا الطلب غير مدعوم.");
        return;
      }

      const authHeader = request.get("Authorization") || "";
      if (!authHeader.startsWith("Bearer ")) {
        fail(response, 401, "unauthorized", "يلزم تسجيل الدخول.");
        return;
      }

      let decoded;
      try {
        decoded = await getAuth().verifyIdToken(authHeader.slice(7));
      } catch (_) {
        fail(response, 401, "unauthorized", "انتهت جلسة الدخول.");
        return;
      }

      const {turnId, messages} = request.body || {};
      const requestedModel = request.body?.model;
      const model = Object.prototype.hasOwnProperty.call(modelAllowlist, requestedModel) ?
        requestedModel : defaultModel;
      const reasoningEffort = modelAllowlist[model];
      const toolsEnabled = !Array.isArray(request.body?.tools) ||
        request.body.tools.length > 0;
      if (typeof turnId !== "string" || turnId.length < 12 || turnId.length > 80 ||
          !validMessages(messages)) {
        fail(response, 400, "invalid_request", "الطلب غير مكتمل.");
        return;
      }

      if (!await consumeQuota(decoded.uid, turnId)) {
        fail(response, 429, "quota_exceeded", "بلغت الحد اليومي — يمكنك المتابعة غدًا.");
        return;
      }

      response.status(200);
      response.set({
        "Content-Type": "text/event-stream; charset=utf-8",
        "Cache-Control": "no-cache, no-transform",
        "Connection": "keep-alive",
        "X-Accel-Buffering": "no",
      });
      response.flushHeaders();

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 25000);
      try {
        const cacheId = crypto.createHash("sha256")
            .update(decoded.uid)
            .digest("hex")
            .slice(0, 32);
        const upstream = await fetch("https://api.x.ai/v1/chat/completions", {
          method: "POST",
          signal: controller.signal,
          headers: {
            "Authorization": `Bearer ${xaiApiKey.value()}`,
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "x-grok-conv-id": cacheId,
          },
          body: JSON.stringify({
            model,
            ...(reasoningEffort ? {reasoning_effort: reasoningEffort} : {}),
            messages: [{role: "system", content: systemPrompt}, ...messages],
            tools: toolsEnabled ? readTools : undefined,
            tool_choice: toolsEnabled ? "auto" : undefined,
            parallel_tool_calls: true,
            stream: true,
            stream_options: {include_usage: true},
            max_tokens: 800,
          }),
        });

        if (!upstream.ok || !upstream.body) {
          sendEvent(response, {
            type: "error",
            code: upstream.status === 429 ? "quota_exceeded" : "upstream_error",
            messageAr: upstream.status === 429 ?
              "خدمة المساعد مشغولة الآن. حاول مجددًا بعد قليل." :
              "تعذّر الوصول إلى المساعد الآن.",
          });
          response.end();
          return;
        }

        const calls = new Map();
        let buffer = "";
        let costUsd = null;
        const decoder = new TextDecoder();
        for await (const chunk of upstream.body) {
          buffer += decoder.decode(chunk, {stream: true});
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";
          for (const rawLine of lines) {
            const line = rawLine.trim();
            if (!line.startsWith("data:")) continue;
            const payload = line.slice(5).trim();
            if (!payload || payload === "[DONE]") continue;
            let event;
            try {
              event = JSON.parse(payload);
            } catch (_) {
              continue;
            }
            const delta = event.choices?.[0]?.delta || {};
            if (typeof delta.content === "string" && delta.content.length > 0) {
              sendEvent(response, {type: "text_delta", text: delta.content});
            }
            for (const callDelta of delta.tool_calls || []) {
              const index = callDelta.index || 0;
              const current = calls.get(index) || {id: "", name: "", arguments: ""};
              if (callDelta.id) current.id = callDelta.id;
              if (callDelta.function?.name) current.name += callDelta.function.name;
              if (callDelta.function?.arguments) {
                current.arguments += callDelta.function.arguments;
              }
              calls.set(index, current);
            }
            const ticks = event.usage?.cost_in_usd_ticks;
            if (typeof ticks === "number") costUsd = ticks / 1e10;
          }
        }

        for (const call of calls.values()) {
          let args = {};
          try {
            args = JSON.parse(call.arguments || "{}");
          } catch (_) {
            sendEvent(response, {
              type: "error",
              code: "invalid_response",
              messageAr: "وصل طلب أداة غير مكتمل من المساعد.",
            });
            response.end();
            return;
          }
          sendEvent(response, {
            type: "tool_call",
            id: call.id,
            name: call.name,
            arguments: args,
          });
        }
        if (costUsd !== null) sendEvent(response, {type: "usage", costUsd});
        sendEvent(response, {type: "done"});
        response.end();
      } catch (error) {
        if (!response.writableEnded) {
          sendEvent(response, {
            type: "error",
            code: error?.name === "AbortError" ? "offline" : "upstream_error",
            messageAr: error?.name === "AbortError" ?
              "استغرق الرد وقتًا أطول من اللازم. حاول مجددًا." :
              "حدثت مشكلة أثناء تشغيل المساعد.",
          });
          response.end();
        }
      } finally {
        clearTimeout(timeout);
      }
    },
);
