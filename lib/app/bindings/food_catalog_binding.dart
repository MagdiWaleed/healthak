import 'package:get/get.dart';

import '../../page/foods/food_catalog_controller.dart';
import '../../service/auth_service.dart';

class FoodCatalogBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(
        // The uid is what enables the user's own components: without one the
        // catalog is still fully browsable, it just has nothing personal to
        // merge in and hides the create button. Guest mode reaches this
        // screen with no signed-in user, so this stays nullable.
        () => FoodCatalogController(
          uid: Get.find<AuthService>().currentUser?.uid,
        ),
      );
}
