import 'package:get/get.dart';
import '../../page/training/plan_editor_screen.dart';
import '../../service/auth_service.dart';

class TrainingEditorBinding extends Bindings {
  @override
  void dependencies() {
    final uid = Get.find<AuthService>().currentUser!.uid;
    Get.lazyPut(() => PlanEditorController(uid: uid));
  }
}
