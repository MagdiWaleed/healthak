# Voice Agent — deferred plan

**Status:** DEFERRED, split out of `plans/step5_ai_agent/` on 2026-09-04 at the boss's
request. Not scheduled. Do not start without an explicit go-ahead — this file is a
holding pen for the spec, not a current to-do.

**Why split out:** Step 5 (`plans/step5_ai_agent/`) no longer treats voice as its final
phase (previously "5V"). The assistant's read/write/coaching/search phases (5A–5D) ship
and are considered complete on their own; voice is optional follow-on work with its own
dependency-approval gate (`speech_to_text`, `flutter_tts` — new packages, need boss
sign-off before any code lands). Keeping it in its own file means Step 5 isn't blocked
waiting on that approval, and this plan doesn't rot un-executed inside a "done" step.

**Depends on:** Step 5 phases 5A–5D shipped (same orchestrator, tools, proposals, undo —
voice is only a new input/output modality on top, zero fork in the pipeline).

---

Voice is another **input modality** on the same pipeline — zero fork in orchestrator,
tools, proposals, or undo.

## Capture

- Package: `speech_to_text` (on-device recognition; Arabic locale fallback chain
  `ar-EG` → `ar-SA` → `ar`). **New dependency — needs boss approval before the phase
  starts; record in Deviations.**
- Interaction: hold-to-talk on the composer's mic button. While held:
  - Live **waveform strip** above the composer — custom painter driven by the plugin's
    sound-level stream, emerald gradient, `RepaintBoundary`, `MotionSettings`-gated
    (reduced motion → static level bar).
  - Partial transcript renders live in the composer field (editable before send —
    speech is a draft, not a commitment).
- Release → final transcript into `ChatOrchestrator.send()`. From here, identical to a
  typed message.

## Responses

- **TTS is opt-in, default off.** Toggle in the assistant's app-bar overflow («اقرا
  الردود»). On: assistant text answers are spoken (`flutter_tts`, Arabic voice, bundled
  with the same dependency approval).
- Proposals **always render visually**, and with TTS on the summary is spoken too:
  «قلت: بدّل الغداء بسلطة التونة. تأكيد؟»
- **Confirmation is tap-only, forever.** Voice never confirms a write in v1 — accidental
  "نعم" protection is deliberate. (Revisit only with a boss decision.)

## Permissions & states

- Mic permission: glass explainer sheet («عشان تكلمني صوت، محتاج المايك») shown before
  the system dialog; denial → the mic button hides and chat continues typed, no nagging.
- Recognition unavailable (no Arabic pack, airplane mode) → graceful chip «التعرف الصوتي
  مش متاح دلوقتي» — typed chat unaffected.

## Exit criteria (when this plan is picked back up)

- Full propose/confirm flow driven by voice end-to-end on a real device with Arabic
  speech; typed path untouched.

## Explicitly out of scope (v1)

- Wake word, continuous conversation, barge-in/interruption.
- Speaker diarization, multi-user voice profiles.
