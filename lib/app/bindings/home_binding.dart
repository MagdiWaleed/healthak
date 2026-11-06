import 'package:get/get.dart';

import '../../page/home/home_controller.dart';
import '../../page/progress/progress_controller.dart';
import '../../page/today/today_controller.dart';
import '../../page/training/training_controller.dart';
import '../../data/repositories/body_weight_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../service/agent/agent_action_log.dart';
import '../../service/agent/agent_conversation_store.dart';
import '../../service/agent/agent_data_source.dart';
import '../../service/agent/agent_tool_registry.dart';
import '../../service/agent/ai_client.dart';
import '../../service/agent/chat_orchestrator.dart';
import '../../service/agent/chat_title_generator.dart';
import '../../service/agent/web_search_client.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';
import '../../service/session_controller.dart';
import '../../service/weigh_in_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    final uid = Get.find<AuthService>().currentUser!.uid;
    Get.lazyPut(HomeController.new);
    Get.lazyPut(() => TrainingController(uid: uid));
    Get.lazyPut(() => ProgressController(uid: uid));
    Get.lazyPut(() => WeighInService(
          weights: BodyWeightRepository(uid: uid),
          profiles: ProfileRepository(),
          session: Get.find<SessionController>(),
        ));
    Get.lazyPut(
      () => TodayController(uid: uid),
    );
    // Registered on their own (not built inline inside ChatOrchestrator's
    // closure) so `lib/page/history_ai/` can `Get.find` the same instances
    // -- the audit log has to see exactly the writes the live chat made.
    //
    // `fenix: true`: the assistant page is reached via `pushHealthak`, which
    // pushes a bare `GetPageRoute` through `Navigator.push` rather than
    // `Get.to()`. That bypasses GetX's own route bookkeeping, and its default
    // SmartManagement was intermittently disposing these the moment that
    // route landed on top of Home -- even though Home never left the stack --
    // producing a "ChatOrchestrator not found" crash on the assistant screen.
    // `fenix` rebuilds from the same builder on the next `Get.find` instead
    // of throwing; safe here since all three reload their state from
    // SharedPreferences on construction anyway.
    Get.lazyPut(
      () => AgentToolRegistry(
        data: HealthakAgentDataSource(uid: uid),
        webSearch: createWebFoodSearchClient(),
        generalWebSearch: createWebSearchClient(),
      ),
      fenix: true,
    );
    Get.lazyPut<AgentActionLog>(SharedPrefsAgentActionLog.new, fenix: true);
    Get.lazyPut(
      () => ChatOrchestrator(
        client: createAiClient(),
        conversationStore: SharedPrefsAgentConversationStore(),
        titleGenerator: createChatTitleGenerator(),
        actionLog: Get.find<AgentActionLog>(),
        resolveModel: () => Get.find<PrefsService>().assistantModelId,
        tools: Get.find<AgentToolRegistry>(),
      ),
      fenix: true,
    );
  }
}
