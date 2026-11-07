const kMinHeightCm = 100;
const kMaxHeightCm = 250;
const kMinWeightKg = 25;
const kMaxWeightKg = 350;
const kMinAgeYears = 13;
const kMaxAgeYears = 100;

enum BodyStatsError { birthYear, height, weight }

BodyStatsError? validateBodyStats({
  required int? birthYear,
  required double? heightCm,
  required double? weightKg,
  required DateTime now,
}) {
  final age = birthYear == null ? null : now.year - birthYear;
  if (age == null || age < kMinAgeYears || age > kMaxAgeYears) {
    return BodyStatsError.birthYear;
  }
  if (heightCm == null ||
      !heightCm.isFinite ||
      heightCm < kMinHeightCm ||
      heightCm > kMaxHeightCm) {
    return BodyStatsError.height;
  }
  if (weightKg == null ||
      !weightKg.isFinite ||
      weightKg < kMinWeightKg ||
      weightKg > kMaxWeightKg) {
    return BodyStatsError.weight;
  }
  return null;
}
