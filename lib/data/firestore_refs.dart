import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/food/food_item.dart';
import '../domain/day/day_log.dart';
import '../domain/market/market_meal.dart';
import '../domain/meal/meal_definition.dart';
import '../domain/profile/user_profile.dart';
import '../domain/schedule/schedule_item.dart';
import 'mappers/day_mapper.dart';
import 'mappers/food_mapper.dart';
import 'mappers/market_mapper.dart';
import 'mappers/meal_mapper.dart';
import 'mappers/profile_mapper.dart';
import 'mappers/schedule_mapper.dart';

/// Owns the typed Firestore collection references used by repositories.
///
/// New collections are added here with a converter before any repository can
/// reach them. This prevents raw Firestore maps escaping a mapper.
class FirestoreRefs {
  final FirebaseFirestore _firestore;

  FirestoreRefs({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference<FoodItem> get foods =>
      _firestore.collection('foods').withConverter<FoodItem>(
            fromFirestore: FoodMapper.fromFirestore,
            toFirestore: FoodMapper.toFirestore,
          );

  /// The user's own components, kept separate from the shared [foods] catalog.
  ///
  /// `foods` is deliberately read-only to clients (`allow write: if false` in
  /// `firestore.rules`) -- it is a shared, public catalog seeded out of band,
  /// and letting any signed-in client write into it would make one user's typo
  /// everybody's data. A component the user creates for themselves therefore
  /// lives under their own document, where the existing
  /// `users/{uid}/{document=**}` rule already grants them full access and
  /// nobody else any. Same [FoodItem] shape and same mapper, so everything
  /// downstream -- the picker, the meal editor, the solver -- treats the two
  /// identically.
  CollectionReference<FoodItem> userFoods(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('foods')
      .withConverter<FoodItem>(
        fromFirestore: FoodMapper.fromFirestore,
        toFirestore: FoodMapper.toFirestore,
      );

  CollectionReference<UserProfile> get profiles =>
      _firestore.collection('users').withConverter<UserProfile>(
            fromFirestore: ProfileMapper.fromFirestore,
            toFirestore: ProfileMapper.toFirestore,
          );

  CollectionReference<MealDefinition> meals(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('meals')
      .withConverter<MealDefinition>(
        fromFirestore: MealMapper.fromFirestore,
        toFirestore: MealMapper.toFirestore,
      );

  CollectionReference<ScheduleItem> schedule(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('schedule')
      .withConverter<ScheduleItem>(
        fromFirestore: ScheduleMapper.fromFirestore,
        toFirestore: ScheduleMapper.toFirestore,
      );

  CollectionReference<DayLog> days(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('days')
      .withConverter<DayLog>(
        fromFirestore: DayMapper.fromFirestore,
        toFirestore: DayMapper.toFirestore,
      );

  CollectionReference<MarketMeal> get marketMeals =>
      _firestore.collection('marketMeals').withConverter<MarketMeal>(
            fromFirestore: MarketMapper.fromFirestore,
            toFirestore: MarketMapper.toFirestore,
          );
}
