import 'package:get/get.dart';

import '../../page/home/home_controller.dart';
import '../../page/today/today_controller.dart';
import '../../service/auth_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(HomeController.new);
    Get.lazyPut(
      () => TodayController(uid: Get.find<AuthService>().currentUser!.uid),
    );
  }
}
