import 'package:get/get.dart';

import '../../page/foods/food_catalog_controller.dart';

class FoodCatalogBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(FoodCatalogController.new);
}
