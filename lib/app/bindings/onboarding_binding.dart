import 'package:get/get.dart';

import '../../data/repositories/profile_repository.dart';
import '../../page/onboarding/onboarding_controller.dart';
import '../../service/auth_service.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(
        () => OnboardingController(
            Get.find<AuthService>(), Get.find<ProfileRepository>()),
      );
}
