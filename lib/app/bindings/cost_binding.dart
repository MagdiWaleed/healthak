import 'package:get/get.dart';

import '../../page/cost/cost_controller.dart';
import '../../service/auth_service.dart';

class CostBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(
        () => CostController(uid: Get.find<AuthService>().currentUser!.uid),
      );
}
