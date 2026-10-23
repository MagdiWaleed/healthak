import 'package:flutter_test/flutter_test.dart';
import 'package:diet_app2/ui/food/food_photo.dart';

void main() {
  test('white rice is not mistaken for eggs in the meal photograph', () {
    expect(
      FoodPhoto.forMeal('وجبة بروتين', ['صدور دجاج', 'ارز ابيض دبق']),
      'asset/image/food/grilled_chicken_rice.jpg',
    );
    expect(
      FoodPhoto.forMeal('فطور خفيف', ['ارز ابيض دبق', 'بيض مسلوق']),
      'asset/image/food/rice_boiled_eggs.jpg',
    );
  });
}
