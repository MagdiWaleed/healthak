import 'package:diet_app2/appData.dart';
import 'package:diet_app2/model/user_model.dart';
import 'package:diet_app2/page/current_diet/current_diet_screen.dart';
import 'package:diet_app2/page/my_informations/create_meals/create_meals_model.dart';
import 'package:diet_app2/page/my_informations/my_informations_screen.dart';
import 'package:diet_app2/page/my_informations/my_males_current_diet/my_males_current_diet_screen.dart';
import 'package:diet_app2/service/create_meals_repository.dart';
import 'package:diet_app2/service/main_repository.dart';
import 'package:diet_app2/service/males_repository.dart';
import 'package:diet_app2/theme/app_colors.dart';
import 'package:diet_app2/widget/custom_background.dart';
import 'package:diet_app2/widget/custom_complete_meal_card.dart';
import 'package:diet_app2/widget/custom_meal_card.dart';
import 'package:diet_app2/widget/custom_multi_choose.dart';
import 'package:diet_app2/widget/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_indicator/loading_indicator.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.me});
  final UserModel me;
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<String> labels = ["الانجاز اليومي", "الرئيسية", "جميع الوجبات"];

  final controller = Get.put(MalesRepository());
  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      CurrentDietScreen(),
      MainBody(),
      ShowMeals(),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15))),
        leading: IconButton(
          onPressed: () async {
            await Get.to(MyInformationScreen())!
                .then((value) => appData.setPageIndex(1));

            setState(() {});
          },
          icon: const Icon(
            Icons.settings,
            size: 20,
            color: Colors.white,
          ),
          style: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(AppColors.buttonColor)),
        ),
        backgroundColor: AppColors.buttonColor,
        title: CustomText(
          title: labels[appData.getPageIndex()],
          fw: FontWeight.bold,
          size: 15,
        ),
        centerTitle: true,
      ),
      body: CustomBackground(
        child: pages[appData.getPageIndex()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.transparent.withOpacity(0.5),
        onTap: (i) {
          setState(() {
            appData.setPageIndex(i);
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: CustomText(
              title: "الانجاز اليومي",
              size: appData.getPageIndex() == 0 ? 18 : 14,
              color: appData.getPageIndex() == 0
                  ? AppColors.buttonColor
                  : Colors.white,
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: CustomText(
              title: "الرئيسية",
              size: appData.getPageIndex() == 1 ? 18 : 14,
              color: appData.getPageIndex() == 1
                  ? AppColors.buttonColor
                  : Colors.white,
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: CustomText(
              title: "جميع المكونات",
              size: appData.getPageIndex() == 2 ? 18 : 14,
              color: appData.getPageIndex() == 2
                  ? AppColors.buttonColor
                  : Colors.white,
            ),
            label: "",
          ),
        ],
      ),
      floatingActionButton: appData.getPageIndex() == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Get.to(MyMalesCurrentDietScreen())!
                    .then((value) => appData.setPageIndex(1));
                ;

                setState(() {});
              },
              label: CustomText(title: "تعديل"),
              backgroundColor: AppColors.buttonColor,
            )
          : Container(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

class ShowMealsController extends GetxController {
  final data = Get.put(CreateMealsRepository());
  Future<List> getData() async {
    try {
      return data.getMeals();
    } catch (e) {
      print(e.toString());
      return [];
    }
  }
}

class ShowMeals extends StatelessWidget {
  const ShowMeals({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: GetBuilder<ShowMealsController>(
        init: ShowMealsController(),
        builder: (_controller) {
          return RefreshIndicator(
            onRefresh: () async {
              _controller.update();
            },
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FutureBuilder(
                  future: _controller.getData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      if (snapshot.hasData) {
                        final List<CreateMealsModel> data =
                            snapshot.data! as List<CreateMealsModel>;
                        return Column(
                          children: [
                            SizedBox(height: 100),
                            for (int i = 0; i < data.length; i++)
                              GestureDetector(
                                onTap: () {},
                                child: CustomCompleteMealCard(
                                  name: data[i].name,
                                  calories: data[i].calories,
                                  carp: data[i].carp,
                                  createdByname: data[i].createdByname,
                                  fat: data[i].fat,
                                  protien: data[i].protein,
                                ),
                              )
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            SizedBox(height: 100),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomText(
                                  title: "there are no data ",
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 100),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 80,
                                width: 80,
                                child: LoadingIndicator(
                                    indicatorType: Indicator.lineScale,
                                    colors: [AppColors.buttonColor],
                                    strokeWidth: 2,
                                    backgroundColor: Colors.transparent,
                                    pathBackgroundColor: Colors.transparent),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MainBody extends StatelessWidget {
  const MainBody({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 100),
            Container(
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(12)),
              width: double.infinity,
              height: 250,
              alignment: Alignment.center,
              child: GetBuilder<MainRepository>(
                init: MainRepository(),
                builder: (controller) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        //  FutureBuilder(
                        //   future: controller.getMainScreenGif(),
                        //   builder: (context, snapshot) {
                        //     if (snapshot.connectionState ==
                        //         ConnectionState.done) {
                        //       if (snapshot.hasData) {
                        //         Gif gif = snapshot.data as Gif;
                        //         return Container(
                        //           height: 250,
                        //           child: Image.network(
                        //             gif.link,
                        //             fit: BoxFit.cover,
                        //           ),
                        //         );
                        //       } else {
                        //         return Center(
                        //           child: CustomText(title: "there is an error"),
                        //         );
                        //       }
                        //     } else {
                        //       return Center(
                        //         child: Container(
                        //           height: 80,
                        //           width: 80,
                        //           child: LoadingIndicator(
                        //               indicatorType: Indicator.lineScale,
                        //               colors: [AppColors.buttonColor],
                        //               strokeWidth: 2,
                        //               backgroundColor: Colors.transparent,
                        //               pathBackgroundColor: Colors.transparent),
                        //         ),
                        //       );
                        //     }
                        //   },
                        // ),
                        Stack(
                      children: [
                        Center(
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
                        ),
                        Container(
                          height: 250,
                          child: Image.asset(
                            'asset/image/main_screen_image.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
