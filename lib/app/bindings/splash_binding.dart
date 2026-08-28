import 'package:get/get.dart';

import '../../data/repositories/profile_repository.dart';
import '../../page/splash/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(
        () => SplashController(
            Get.find(), Get.find(), Get.find<ProfileRepository>()),
      );
}
