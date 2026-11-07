import 'macros.dart';

const double kMinPortionGrams = 1;
const double kMaxPortionGrams = 5000;
const double kMaxManualEntryKcal = 10000;
const double kMaxEntryMacroGrams = 1000;
const double kMaxPer100MacroGrams = 100;
const double kMaxPer100Kcal = 900;
const double kMinPrice = 0;

bool isPortionGrams(double? grams) =>
    grams != null &&
    grams.isFinite &&
    grams >= kMinPortionGrams &&
    grams <= kMaxPortionGrams;

bool isManualEntryMacros(Macros macros) =>
    macros.protein.isFinite &&
    macros.carbs.isFinite &&
    macros.fat.isFinite &&
    macros.protein >= 0 &&
    macros.protein <= kMaxEntryMacroGrams &&
    macros.carbs >= 0 &&
    macros.carbs <= kMaxEntryMacroGrams &&
    macros.fat >= 0 &&
    macros.fat <= kMaxEntryMacroGrams &&
    macros.kcal <= kMaxManualEntryKcal;

bool isCatalogMacros(Macros macros) =>
    macros.protein.isFinite &&
    macros.carbs.isFinite &&
    macros.fat.isFinite &&
    macros.protein >= 0 &&
    macros.carbs >= 0 &&
    macros.fat >= 0 &&
    macros.protein + macros.carbs + macros.fat <= kMaxPer100MacroGrams &&
    macros.kcal <= kMaxPer100Kcal;

bool isPrice(double? price) =>
    price != null && price.isFinite && price >= kMinPrice;
