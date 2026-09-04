import 'package:get/get.dart';

import '../../page/home/home_controller.dart';
import '../../page/today/today_controller.dart';
import '../../service/agent/agent_action_log.dart';
import '../../service/agent/agent_conversation_store.dart';
import '../../service/agent/agent_data_source.dart';
import '../../service/agent/agent_tool_registry.dart';
import '../../service/agent/ai_client.dart';
import '../../service/agent/chat_orchestrator.dart';
import '../../service/agent/chat_title_generator.dart';
import '../../service/agent/web_food_search_client.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    final uid = Get.find<AuthService>().currentUser!.uid;
    Get.lazyPut(HomeController.new);
    Get.lazyPut(
      () => TodayController(uid: uid),
    );
    // Registered on their own (not built inline inside ChatOrchestrator's
    // closure) so `lib/page/history_ai/` can `Get.find` the same instances
    // -- the audit log has to see exactly the writes the live chat made.
    Get.lazyPut(
      () => AgentToolRegistry(
        data: HealthakAgentDataSource(uid: uid),
        webSearch: createWebFoodSearchClient(),
      ),
    );
    Get.lazyPut<AgentActionLog>(SharedPrefsAgentActionLog.new);
    Get.lazyPut(
      () => ChatOrchestrator(
        client: createAiClient(),
        conversationStore: SharedPrefsAgentConversationStore(),
        titleGenerator: createChatTitleGenerator(),
        actionLog: Get.find<AgentActionLog>(),
        resolveModel: () => Get.find<PrefsService>().assistantModelId,
        tools: Get.find<AgentToolRegistry>(),
      ),
    );
  }
}
