import 'dart:async';

import 'package:diet_app2/appData.dart';
import 'package:diet_app2/model/complete_male_model.dart';
import 'package:diet_app2/model/user_model.dart';
import 'package:diet_app2/page/add_complete_meal/add_complete_meal_controller.dart';
import 'package:diet_app2/page/my_informations/my_males_current_diet/my_males_current_diet_screen.dart';
import 'package:diet_app2/page/single_male_screen/single_male_model.dart';
import 'package:diet_app2/page/single_male_screen/single_male_screen.dart';
import 'package:diet_app2/theme/app_colors.dart';
import 'package:diet_app2/widget/custom_meal_card.dart';
import 'package:diet_app2/widget/custom_text.dart';
import 'package:diet_app2/widget/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_indicator/loading_indicator.dart';

class AddCompleteMealScreen extends StatelessWidget {
  final TextEditingController _textEditingController = TextEditingController();

  AddCompleteMealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.buttonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
        title: CustomText(
          title: "اختار المكونات",
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: CustomTextField(
                  title: "حد معين من الكالوريز؟",
                  controller: _textEditingController,
                  textInputType: TextInputType.number,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: GetBuilder<AddCompleteMealController>(
                    init: AddCompleteMealController(),
                    builder: (controller) {
                      return FutureBuilder(
                        future: controller.getData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            if (snapshot.hasData) {
                              List<SingleMaleModel> data =
                                  snapshot.data as List<SingleMaleModel>;
                              return Column(
                                children: [
                                  for (int i = 0; i < data.length; i++)
                                    GetBuilder<AddCompleteMealController>(
                                        init: AddCompleteMealController(),
                                        id: data[i].id,
                                        builder: (context) {
                                          return Stack(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  controller
                                                      .addComponent(data[i]);
                                                },
                                                onLongPress: () {
                                                  Get.to(SingleMaleScreen(
                                                      singleMaleModel:
                                                          data[i]));
                                                },
                                                child: CustomMealCard(
                                                  name: data[i].name,
                                                  calories: data[i]
                                                      .getCalories()
                                                      .toPrecision(2),
                                                ),
                                              ),
                                              controller.myComponentIds
                                                      .contains(data[i].id)
                                                  ? GestureDetector(
                                                      onTap: () {
                                                        controller
                                                            .removeComponent(
                                                                data[i]);
                                                      },
                                                      child: Container(
                                                        height: 90,
                                                        width: double.infinity,
                                                        child: Icon(
                                                          Icons.done,
                                                          color: Colors.white,
                                                          size: 40,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .buttonColor
                                                              .withOpacity(0.5),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                      ),
                                                    )
                                                  : Container()
                                            ],
                                          );
                                        })
                                ],
                              );
                            } else {
                              return Container(
                                alignment: Alignment.center,
                                width: double.infinity,
                                color: Colors.black,
                                height: 300,
                                child: CustomText(
                                  title: "there are no data ",
                                ),
                              );
                            }
                          } else {
                            return Center(
                              child: Container(
                                height: 80,
                                width: 80,
                                child: LoadingIndicator(
                                    indicatorType: Indicator.lineScale,
                                    colors: [AppColors.buttonColor],
                                    strokeWidth: 2,
                                    backgroundColor: Colors.transparent,
                                    pathBackgroundColor: Colors.transparent),
                              ),
                            );
                          }
                        },
                      );
                    }),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final controller = Get.find<AddCompleteMealController>();
          CompleteMaleModel completmale = CompleteMaleModel(
              components: controller.myMeals,
              id: "fadsfasd",
              name: "وجبة",
              isEaten: false);
          completmale.setCustomCalories(_textEditingController.text);

          appData.getUserModel().myDietMales.add(completmale);
          controller.saveToSharedPrefrences(completmale);
          await controller.updateMealName();
          unawaited(Get.off(() => MyMalesCurrentDietScreen()));
          print(completmale.custom_calories);
        },
        label: CustomText(title: "دن"),
        backgroundColor: AppColors.buttonColor,
      ),
    );
  }
}
