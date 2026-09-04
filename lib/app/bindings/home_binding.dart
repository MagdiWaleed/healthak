import 'package:get/get.dart';

import '../../page/home/home_controller.dart';
import '../../page/today/today_controller.dart';
import '../../service/agent/agent_conversation_store.dart';
import '../../service/agent/agent_data_source.dart';
import '../../service/agent/agent_tool_registry.dart';
import '../../service/agent/ai_client.dart';
import '../../service/agent/chat_orchestrator.dart';
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
    Get.lazyPut(
      () => ChatOrchestrator(
        client: createAiClient(),
        conversationStore: SharedPrefsAgentConversationStore(),
        resolveModel: () => Get.find<PrefsService>().assistantModelId,
        tools: AgentToolRegistry(
          data: HealthakAgentDataSource(uid: uid),
        ),
      ),
    );
  }
}
