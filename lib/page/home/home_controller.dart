import 'package:get/get.dart';

class HomeController extends GetxController {
  final tabIndex = 0.obs;
  void selectTab(int index) => tabIndex.value = index;
}
