enum MuscleGroup {
  chest,
  back,
  shoulders,
  arms,
  legs,
  glutes,
  core,
  cardio,
  fullBody,
}

class Exercise {
  final String id;
  final String nameAr;
  final MuscleGroup muscle;
  final bool isCustom;
  const Exercise({
    required this.id,
    required this.nameAr,
    required this.muscle,
    this.isCustom = false,
  });
}

const kExerciseLibrary = <Exercise>[
  Exercise(
    id: 'bench_press',
    nameAr: 'ضغط بالبار على البنش',
    muscle: MuscleGroup.chest,
  ),
  Exercise(
    id: 'incline_bench_press',
    nameAr: 'ضغط بنش مائل بالبار',
    muscle: MuscleGroup.chest,
  ),
  Exercise(
    id: 'decline_bench_press',
    nameAr: 'ضغط بنش منخفض',
    muscle: MuscleGroup.chest,
  ),
  Exercise(
    id: 'dumbbell_bench_press',
    nameAr: 'ضغط بنش بالدمبل',
    muscle: MuscleGroup.chest,
  ),
  Exercise(
    id: 'incline_dumbbell_press',
    nameAr: 'ضغط دمبل مائل',
    muscle: MuscleGroup.chest,
  ),
  Exercise(
    id: 'chest_fly',
    nameAr: 'تفتيح صدر بالدمبل',
    muscle: MuscleGroup.chest,
  ),
  Exercise(
    id: 'cable_fly',
    nameAr: 'تفتيح صدر بالكابل',
    muscle: MuscleGroup.chest,
  ),
  Exercise(id: 'push_up', nameAr: 'ضغط أرضي', muscle: MuscleGroup.chest),
  Exercise(id: 'deadlift', nameAr: 'رفعة مميتة', muscle: MuscleGroup.back),
  Exercise(id: 'lat_pulldown', nameAr: 'سحب أمامي', muscle: MuscleGroup.back),
  Exercise(id: 'pull_up', nameAr: 'عقلة', muscle: MuscleGroup.back),
  Exercise(id: 'chin_up', nameAr: 'عقلة قبضة معكوسة', muscle: MuscleGroup.back),
  Exercise(id: 'barbell_row', nameAr: 'تجديف بالبار', muscle: MuscleGroup.back),
  Exercise(
    id: 'dumbbell_row',
    nameAr: 'تجديف بالدمبل',
    muscle: MuscleGroup.back,
  ),
  Exercise(
    id: 'seated_cable_row',
    nameAr: 'تجديف بالكابل جالساً',
    muscle: MuscleGroup.back,
  ),
  Exercise(
    id: 'straight_arm_pulldown',
    nameAr: 'سحب مستقيم بالكابل',
    muscle: MuscleGroup.back,
  ),
  Exercise(
    id: 'overhead_press',
    nameAr: 'ضغط كتف بالبار',
    muscle: MuscleGroup.shoulders,
  ),
  Exercise(
    id: 'dumbbell_shoulder_press',
    nameAr: 'ضغط كتف بالدمبل',
    muscle: MuscleGroup.shoulders,
  ),
  Exercise(
    id: 'arnold_press',
    nameAr: 'ضغط أرنولد',
    muscle: MuscleGroup.shoulders,
  ),
  Exercise(
    id: 'lateral_raise',
    nameAr: 'رفرفة جانبية',
    muscle: MuscleGroup.shoulders,
  ),
  Exercise(
    id: 'front_raise',
    nameAr: 'رفرفة أمامية',
    muscle: MuscleGroup.shoulders,
  ),
  Exercise(
    id: 'rear_delt_fly',
    nameAr: 'رفرفة خلفية',
    muscle: MuscleGroup.shoulders,
  ),
  Exercise(id: 'face_pull', nameAr: 'سحب للوجه', muscle: MuscleGroup.shoulders),
  Exercise(
    id: 'upright_row',
    nameAr: 'سحب بار للذقن',
    muscle: MuscleGroup.shoulders,
  ),
  Exercise(
    id: 'barbell_curl',
    nameAr: 'ثني ذراع بالبار',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'dumbbell_curl',
    nameAr: 'ثني ذراع بالدمبل',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'hammer_curl',
    nameAr: 'ثني ذراع قبضة مطرقة',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'preacher_curl',
    nameAr: 'ثني ذراع على كرسي الواعظ',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'cable_curl',
    nameAr: 'ثني ذراع بالكابل',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'triceps_pushdown',
    nameAr: 'دفع ترايسبس بالكابل',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'skull_crusher',
    nameAr: 'تمديد ترايسبس بالبار',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'overhead_triceps',
    nameAr: 'تمديد ترايسبس فوق الرأس',
    muscle: MuscleGroup.arms,
  ),
  Exercise(
    id: 'barbell_squat',
    nameAr: 'سكوات بالبار',
    muscle: MuscleGroup.legs,
  ),
  Exercise(id: 'front_squat', nameAr: 'سكوات أمامي', muscle: MuscleGroup.legs),
  Exercise(
    id: 'goblet_squat',
    nameAr: 'سكوات بالكأس',
    muscle: MuscleGroup.legs,
  ),
  Exercise(id: 'leg_press', nameAr: 'ضغط أرجل', muscle: MuscleGroup.legs),
  Exercise(id: 'leg_extension', nameAr: 'تمديد أرجل', muscle: MuscleGroup.legs),
  Exercise(id: 'leg_curl', nameAr: 'ثني أرجل', muscle: MuscleGroup.legs),
  Exercise(
    id: 'walking_lunge',
    nameAr: 'اندفاع بالمشي',
    muscle: MuscleGroup.legs,
  ),
  Exercise(id: 'calf_raise', nameAr: 'رفع السمانة', muscle: MuscleGroup.legs),
  Exercise(id: 'hip_thrust', nameAr: 'دفع الحوض', muscle: MuscleGroup.glutes),
  Exercise(
    id: 'glute_bridge',
    nameAr: 'جسر الأرداف',
    muscle: MuscleGroup.glutes,
  ),
  Exercise(
    id: 'bulgarian_split_squat',
    nameAr: 'سكوات بلغاري',
    muscle: MuscleGroup.glutes,
  ),
  Exercise(
    id: 'cable_kickback',
    nameAr: 'رفس خلفي بالكابل',
    muscle: MuscleGroup.glutes,
  ),
  Exercise(
    id: 'romanian_deadlift',
    nameAr: 'رفعة رومانية',
    muscle: MuscleGroup.glutes,
  ),
  Exercise(
    id: 'step_up',
    nameAr: 'صعود على الصندوق',
    muscle: MuscleGroup.glutes,
  ),
  Exercise(id: 'plank', nameAr: 'بلانك', muscle: MuscleGroup.core),
  Exercise(id: 'side_plank', nameAr: 'بلانك جانبي', muscle: MuscleGroup.core),
  Exercise(id: 'crunch', nameAr: 'كرنش', muscle: MuscleGroup.core),
  Exercise(id: 'leg_raise', nameAr: 'رفع الساقين', muscle: MuscleGroup.core),
  Exercise(
    id: 'russian_twist',
    nameAr: 'التواء روسي',
    muscle: MuscleGroup.core,
  ),
  Exercise(
    id: 'bicycle_crunch',
    nameAr: 'كرنش الدراجة',
    muscle: MuscleGroup.core,
  ),
  Exercise(id: 'ab_wheel', nameAr: 'عجلة البطن', muscle: MuscleGroup.core),
  Exercise(
    id: 'treadmill_run',
    nameAr: 'جري على السير',
    muscle: MuscleGroup.cardio,
  ),
  Exercise(
    id: 'treadmill_walk',
    nameAr: 'مشي على السير',
    muscle: MuscleGroup.cardio,
  ),
  Exercise(
    id: 'stationary_bike',
    nameAr: 'دراجة ثابتة',
    muscle: MuscleGroup.cardio,
  ),
  Exercise(
    id: 'rowing_machine',
    nameAr: 'جهاز التجديف',
    muscle: MuscleGroup.cardio,
  ),
  Exercise(
    id: 'elliptical',
    nameAr: 'جهاز الأوربتراك',
    muscle: MuscleGroup.cardio,
  ),
  Exercise(id: 'jump_rope', nameAr: 'نط الحبل', muscle: MuscleGroup.cardio),
  Exercise(
    id: 'stair_climber',
    nameAr: 'صعود الدرج',
    muscle: MuscleGroup.cardio,
  ),
];

Exercise? exerciseById(String id) {
  for (final exercise in kExerciseLibrary) {
    if (exercise.id == id) return exercise;
  }
  return null;
}

String muscleLabelAr(MuscleGroup muscle) => switch (muscle) {
      MuscleGroup.chest => 'الصدر',
      MuscleGroup.back => 'الظهر',
      MuscleGroup.shoulders => 'الأكتاف',
      MuscleGroup.arms => 'الذراعان',
      MuscleGroup.legs => 'الساقان',
      MuscleGroup.glutes => 'الأرداف',
      MuscleGroup.core => 'الجذع',
      MuscleGroup.cardio => 'تمارين القلب',
      MuscleGroup.fullBody => 'الجسم بالكامل',
    };
