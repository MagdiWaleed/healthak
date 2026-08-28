import 'package:diet_app2/appData.dart';
import 'package:diet_app2/model/complete_male_model.dart';
import 'package:diet_app2/model/statistics.dart';
import 'package:diet_app2/model/user_model.dart';
import 'package:diet_app2/page/current_diet/current_diet_controller.dart';
import 'package:diet_app2/page/my_informations/my_males_current_diet/complete_male/complete_male_screen.dart';
import 'package:diet_app2/page/my_informations/my_males_current_diet/my_males_current_diet_controller.dart';
import 'package:diet_app2/page/single_male_screen/single_male_model.dart';
import 'package:diet_app2/service/statistics_repository.dart';
import 'package:diet_app2/service/user_service.dart';
import 'package:diet_app2/theme/app_colors.dart';
import 'package:diet_app2/widget/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quickalert/quickalert.dart';


class CompleteMaleController extends GetxController {
  int maleIndex;
  TextEditingController controller = TextEditingController();
   TextEditingController caloriesController = TextEditingController();

  CompleteMaleController({required this.maleIndex});
  String name = ""; //todo create button to change the name of the male
  double protein = 0, fats = 0, carps = 0, calories = 0;
  List<SingleMaleModel> components = [];
  @override
  void onInit() {
    for (int i = 0;
        i < appData.getUserModel().myDietMales[maleIndex].components.length;
        i++)
      components
          .add(appData.getUserModel().myDietMales[maleIndex].components[i]);
    
    
    calculatDetails();
    controller.text = appData.getUserModel().myDietMales[maleIndex].name;
   caloriesController.text  = appData.getUserModel().myDietMales[maleIndex].custom_calories.toString();
    super.onInit();
  }

  void onSaveUpdatedCompleteMale() {
    final data = Get.put(UserService());
    final m = appData.getUserModel();
    m.myDietMales[maleIndex].components = components;
    for (int i = 0; i < components.length; i++) {
      m.myDietMales[maleIndex].setNewWeight(i, components[i].weight);
    }

    CompleteMaleModel male = CompleteMaleModel(
        name: controller.text,
        components: components,
        id: "",
        isEaten: appData.getUserModel().myDietMales[maleIndex].isEaten);
    data.updateCompeletMealToDiet(male, maleIndex);

    m.myDietMales[maleIndex].name = male.name;

    appData.setUserModel(m);
    Get.find<MyMalesCurrentDietController>().calculat();
  }

  void onDeleteCompleteMale(int index) {
    final data = Get.put(UserService());
    data.deleteCompeletMealToDiet(index);
    UserModel m = appData.getUserModel();
    m.myDietMales.removeAt(index);
    appData.setUserModel(m);
    Get.find<MyMalesCurrentDietController>().calculat();
  }

  void calculatDetails() {
    protein = 0;
    fats = 0;
    carps = 0;
    calories = 0;

    for (int i = 0; i < components.length; i++) {
      protein += components[i].getProtein();
      carps += components[i].getCarps();
      fats += components[i].getFats();
      calories += components[i].getCalories();
    }
  }

  // Interim proportional-scale solver. Replaces the TFLite model, which was hardcoded
  // to exactly 3 components and had several index bugs. The real solver with per-entry
  // locks lands in step 2; this keeps the legacy screen working until then.
  void autoChangeWeight() {
    final target = double.tryParse(caloriesController.text);
    if (target == null || target <= 0 || components.isEmpty) return;

    double current = 0;
    for (final c in components) {
      current += c.getCalories();
    }
    if (current <= 0) return;

    final factor = target / current;
    for (final c in components) {
      c.setWeight((c.weight * factor / 5).round() * 5.0);
    }

    calculatDetails();
    update();
  }

  void editThisComponent(int index) {
    double helperForCurrentWieght = 0;
    Get.defaultDialog(
        title: "ادخل الكمية الجديدة:",
        titleStyle: TextStyle(fontSize: 15, fontFamily: "Cairo"),
        content: Container(
          decoration: BoxDecoration(
            color: AppColors.buttonColor,
            borderRadius: BorderRadius.circular(
              12,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: TextField(
            style: TextStyle(
                color: Colors.white,
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: AppColors.buttonColor, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.loading, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide:
                    BorderSide(color: AppColors.buttonColor, width: 0.5),
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 10),
                  CustomText(title: "الكمية"),
                  SizedBox(width: 2),
                ],
              ),
            ),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            onChanged: (t) {
              if (t != "") {
                helperForCurrentWieght = double.parse(t);
              }
            },
          ),
        ),
        textConfirm: "حفظ",
        buttonColor: AppColors.buttonColor,
        textCancel: "الغاء",
        onConfirm: () {
          components[index].setWeight(helperForCurrentWieght);
          calculatDetails();
          update();

          Get.back();
        });
  }
  
  void uploadThisMeal(  BuildContext context) async{
    double meal_calories = 0;
    List<double> weights= [];
    List<String> names = [];
    if (caloriesController.text != "" && double.parse(caloriesController.text)!=0){
      meal_calories =double.parse( caloriesController.text);
    }
    for (SingleMaleModel component in components){
      weights.add(component.weight);
      names.add(component.name);
    }
    QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "",
        widget: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomText(
              title: "مهلا! هل انت متأكد؟",
              size: 16,
              color: Colors.black,
            ),
          ],
        ),
        showConfirmBtn:true,
        showCancelBtn: true,
        onConfirmBtnTap: ()async{
          Statistics data = Statistics(weights: weights, names: names, calories: meal_calories);
          await StatisticsRepository.addMealData(data);
          Get.back();
        }
      );
  }
  void getTheRestOfCalories(){
      double restOfCalories = 0.0;
for(int i = 0; i < appData.getUserModel().myDietMales.length; i++){
      if(i != maleIndex){
        restOfCalories+= appData.getUserModel().myDietMales[i].calories;
        print( appData.getUserModel().myDietMales[i].calories);
      }
    } 
    restOfCalories = appData.getUserModel().caloriesGoal! - restOfCalories;
    caloriesController.text = restOfCalories.toPrecision(2).toString();
   print(restOfCalories);
    update();
  }

void deleteSingleComponent(int index){
  //  final data = Get.put(UserService());
  //   data.deleteCompeletMealToDiet(index);
  //   UserModel m = appData.getUserModel();
    components.removeAt(index);
    update();
    // appData.setUserModel(m);
    // Get.find<MyMalesCurrentDietController>().calculat();

}
}
