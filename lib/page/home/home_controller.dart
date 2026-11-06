import 'package:get/get.dart';

enum HomeTab { today, nutrition, training, progress, me }

class HomeController extends GetxController {
  final tabIndex = 0.obs;
  void selectTab(int index) => goTo(HomeTab.values[index]);
  void goTo(HomeTab tab) => tabIndex.value = tab.index;
}
