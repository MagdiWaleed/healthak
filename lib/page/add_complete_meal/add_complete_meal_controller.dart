import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diet_app2/appData.dart';
import 'package:diet_app2/model/complete_male_model.dart';
import 'package:diet_app2/page/current_diet/current_diet_controller.dart';
import 'package:diet_app2/page/my_informations/my_males_current_diet/my_males_current_diet_controller.dart';
import 'package:diet_app2/page/single_male_screen/single_male_model.dart';
import 'package:diet_app2/service/males_repository.dart';
import 'package:diet_app2/service/user_service.dart';
import 'package:diet_app2/theme/app_colors.dart';
import 'package:diet_app2/widget/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AddCompleteMealController extends GetxController {
  final data = Get.put(MalesRepository());
  final userService = Get.put(UserService());

  List<String> myComponentIds = [];
  List<SingleMaleModel> myMeals = [];
  void addComponent(SingleMaleModel id) {
    myComponentIds.add(id.id);
    myMeals.add(id);
    update([id.id.toString()]);
  }

  void removeComponent(SingleMaleModel id) {
    myComponentIds.remove(id.id);
    myMeals.remove(id);
    update([id.id.toString()]);
  }

  void saveToSharedPrefrences(CompleteMaleModel completeMale) {
    userService.addCompeletMealToDiet(completeMale);
    Get.find<MyMalesCurrentDietController>().calculat();
  }

  Future<void> updateMealName() async {
    String helper = "";

    await Get.defaultDialog(
        title: "اسم الوجبة",
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
                borderSide: BorderSide(color: Colors.white, width: 1),
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
                  CustomText(title: "الاسم"),
                  SizedBox(width: 2),
                ],
              ),
            ),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.name,
            onChanged: (t) {
              if (t != "") {
                helper = t.toString();
              }
            },
          ),
        ),
        textConfirm: "حفظ",
        buttonColor: AppColors.buttonColor,
        textCancel: "الغاء",
        onConfirm: () {
          final m = appData.getUserModel();
          final size = appData.getUserModel().myDietMales.length;
          m.myDietMales[size - 1].name = helper;
          appData.setUserModel(m);

          Get.back();
          Get.find<MyMalesCurrentDietController>().update();
        });
  }

  Future<List> getData() async {
    try {
      return data.getAllSingleMeals();
    } catch (e) {
      print(e);
      return [];
    }
  }
}
