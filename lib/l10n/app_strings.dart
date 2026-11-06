/// Arabic copy shared by new screens.
///
/// Legacy screens keep their original inline strings until Step 2 replaces
/// them. New work uses this file so wording does not drift across screens.
abstract final class AppStrings {
  static const nutrition = 'التغذية';
  static const training = 'التمارين';
  static const progress = 'التقدم';
  static const me = 'أنا';
  static const trainingEmptyTitle = 'خطتك التدريبية قريباً';
  static const trainingEmptyMessage = 'ستظهر هنا تمارينك الأسبوعية.';
  static const progressEmptyTitle = 'تقدمك قريباً';
  static const progressEmptyMessage = 'ستظهر هنا اتجاهات وزنك وإنجازاتك.';
  static const currentWeight = 'الوزن الحالي';
  static const goalWeight = 'الوزن المستهدف';
  static const notSet = 'غير محدد';
  static const kg = 'كجم';
  static const profileAndGoals = 'الملف الشخصي والأهداف';
  static const history = 'السجل';
  static const foodCatalog = 'تصفح المكوّنات';
  static const budget = 'الميزانية';
  static const goalWeightSaved = 'تم حفظ الوزن المستهدف';
  static const save = 'حفظ';
  static const quickAdd = 'إضافة سريعة';
  static const logFood = 'تسجيل طعام';
  static const logWeight = 'تسجيل وزن';
  static const startWorkout = 'ابدأ التمرين';
  static const weightDate = 'تاريخ الوزن';
  static const weightSaved = 'تم حفظ الوزن';
  static const invalidWeight = 'أدخل وزناً بين 25 و350 كجم';
  static const skipGoalWeight = 'تخطي الوزن المستهدف';
  static String streakDays(int count) => '$count أيام متتالية';
  static const todayEnergy = 'المأكول اليوم';
  static const remaining = 'المتبقي';
  static const aboveTarget = 'فوق الهدف';
  static const todayMeals = 'وجبات اليوم';
  static const plannedDetails = 'عرض المخطط لليوم';
  static const noDayRecord = 'لا يوجد سجل لهذا اليوم';
  static const noMealsToday = 'لا توجد وجبات اليوم';
  static const startWithMeal = 'ابدأ بإضافة وجبة أو مكوّن من طعامك';
  static const backToToday = 'العودة لليوم';
  static const dayRecord = 'سجل اليوم';
  static const previousLoggedDay = 'اليوم المسجّل السابق';
  static const nextLoggedDay = 'اليوم المسجّل التالي';
  static const deleteDayEntryTitle = 'حذف الوجبة من اليوم؟';
  static const deleteDayEntryBody = 'ستُحذف من سجل هذا اليوم فقط.';
  static const signOutTitle = 'تسجيل الخروج؟';
  static const signOutBody = 'يمكنك الدخول مجددًا للوصول إلى بياناتك.';
  static const signOut = 'تسجيل الخروج';
  static const removeFromScheduleTitle = 'إزالة الوجبة من الجدول؟';
  static const removeFromScheduleBody = 'لن تظهر تلقائيًا في الأيام القادمة.';
  static const todaySubtitle = 'كل وجبة خطوة نحو هدفك';
  static const historyReadOnly = 'للتصحيح، اضغط تعديل أولاً';
  static const askAssistant = 'اسأل مساعد صحتك';
  static const assistantEntryHint = 'سجّل وجبة، أو اسأل عن المتبقي من هدفك';
  static const mealActions = 'خيارات الوجبة';
  static const assistantConfirmNote = 'لن يُنفّذ الاقتراح قبل تأكيدك';
  static const assistantOptions = 'خيارات المساعد';
  static const manualEntryTitle = 'إضافة طبق يدوي';
  static const manualEntryHint =
      'أدخل القيم للكمية التي ستسجّلها. تُحفظ في هذا اليوم فقط.';
  static const dishName = 'اسم الطبق';
  static const addToDay = 'إضافة لليوم';
  static const saving = 'جارٍ الحفظ…';
  static const saveFailed = 'تعذّر الحفظ. بياناتك ما زالت هنا، حاول مرة أخرى.';
  static const invalidNutrition =
      'أدخل أرقامًا صحيحة غير سالبة للقيم الغذائية.';
  static const chooseMealSlot = 'موعد الوجبة';
  static const automaticMealSlot = 'تلقائي حسب وقت الإضافة';
  static const dayNotEditable =
      'لم يعد هذا اليوم متاحًا للتعديل. ارجع واختر اليوم مجددًا.';
  static const entryAdded = 'أُضيف الطبق إلى يومك';
  static const quickFoodPortionTitle = 'حدّد كمية المكوّن';
  static const portionGrams = 'الكمية بالجرام';
  static const invalidPortion = 'أدخل كمية أكبر من صفر.';
  static const quickFoodAdded = 'أُضيف المكوّن إلى يومك';
  static const quickFoodSaveFailed =
      'تعذّرت إضافة المكوّن. الكمية ما زالت هنا، حاول مرة أخرى.';
  static String portionCalories(int kcal) => '$kcal سعرة لهذه الكمية';
  static const noDayChange = 'عُد لليوم لإضافة طعامك';
  static String calculatedKcal(int kcal) => '$kcal سعرة (محسوبة تلقائيًا)';
  static const weekdayShort = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];
  static const weekdays = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد'
  ];
  static String outOfKcal(int target) => 'من $target سعرة';
  static String energyProgress(int value, int target) =>
      '$value من $target سعرة';
  static String macroAmount(int value, int target) => '$value من $target ج';
  static String plannedSummary(int kcal, int protein, int carbs, int fat) =>
      '$kcal سعرة مخططة · بروتين $protein ج · كارب $carbs ج · دهون $fat ج';
  static String entryNutrition(int kcal, int protein) =>
      '$kcal سعرة · $protein ج بروتين';
  static String foodPer100(int kcal) => '$kcal سعرة / 100 ج';
  static String foodMacrosCompact(int protein, int carbs, int fat) =>
      'بروتين $protein · كارب $carbs · دهون $fat ج';
  static String eatenLabel(String name) => 'تم تناول $name';
  static const appName = 'صحتك';
  static const guestMode = 'وضع الضيف';
  static const guestHeadline = 'استكشف صحتك قبل إنشاء حساب';
  static const guestDescription =
      'شاهد شكل المتابعة اليومية والوجبات. أنشئ حساباً لحفظ بياناتك ومزامنتها.';
  static const signInOrCreateAccount = 'تسجيل الدخول أو إنشاء حساب';
  static const previewOnly = 'معاينة فقط';
  static const dailyTarget = 'هدف اليوم';
  static const mealIdeas = 'أفكار وجبات';
  static const done = 'تم';
  static const edit = 'تعديل';
  static const delete = 'حذف';
  static const addMeal = 'إضافة وجبة';
  static const newMeal = 'وجبة جديدة';
  static const accountNeeded = 'يلزم حساب للحفظ والتتبع';
  static const email = 'البريد الإلكتروني';
  static const password = 'كلمة المرور';
  static const displayName = 'الاسم';
  static const signIn = 'تسجيل الدخول';
  static const createAccount = 'إنشاء حساب';
  static const resetPassword = 'إرسال رابط استعادة كلمة المرور';
  static const continueText = 'متابعة';
  static const saveProfile = 'حفظ الملف وبدء المتابعة';
  static const birthYear = 'سنة الميلاد';
  static const height = 'الطول بالسنتيمتر';
  static const weight = 'الوزن بالكيلوجرام';
  static const today = 'اليوم';
  static const myMeals = 'وجباتي';
  static const market = 'السوق';
  static const marketIntro = 'وجبات من المجتمع يمكنك حفظ نسخة مستقلة منها.';
  static const marketNewest = 'الأحدث';
  static const marketMostCopied = 'الأكثر استخدامًا';
  static const marketLoadFailed = 'تعذّر تحميل وجبات السوق.';
  static const marketEmptyTitle = 'لا توجد وجبات منشورة بعد';
  static const marketEmptyBody = 'ستظهر هنا الوجبات التي ينشرها المجتمع.';
  static const marketMore = 'عرض المزيد';
  static const marketCopies = 'نسخة';
  static const marketCopyTitle = 'حفظ الوجبة في مكتبتي؟';
  static const marketCopyBody =
      'ستُحفظ نسخة خاصة يمكنك تعديلها دون تغيير وجبة الناشر.';
  static const marketCopy = 'حفظ في مكتبتي';
  static const marketCopied = 'حُفظت في مكتبتي';
  static const marketCopyFailed = 'تعذّر حفظ الوجبة. حاول مرة أخرى.';
  static const marketIngredients = 'المكونات';
  static const marketResetWeights = 'استعادة الأوزان الأصلية';
  static const marketInvalidWeights = 'أدخل كمية بين 1 و2000 ج لكل مكوّن.';
  static const marketAddToday = 'أضف لليوم';
  static String marketAddTodayBody(String name, String slot) =>
      'ستُضاف "$name" إلى $slot اليوم بالكميات التي اخترتها.';
  static const marketAddedToday = 'أُضيفت الوجبة إلى اليوم.';
  static const marketAddFailed = 'تعذّر إضافة الوجبة إلى اليوم.';
  static const marketAddSchedule = 'أضف لجدولي';
  static const marketScheduleDays = 'أيام التكرار';
  static const marketScheduleBody =
      'ستُحفظ نسخة خاصة من الوجبة وتُضاف إلى جدولك في الأيام المختارة.';
  static const marketInvalidSchedule = 'اختر يومًا واحدًا على الأقل.';
  static const marketScheduled = 'أُضيفت الوجبة إلى جدولك.';
  static const marketScheduleFailed = 'تعذّر إضافة الوجبة إلى الجدول.';
  static const marketPublish = 'نشر في السوق';
  static const marketUnpublish = 'إلغاء النشر';
  static const marketUnpublishBody =
      'ستختفي الوجبة من السوق، وستبقى النسخ التي حفظها الآخرون مستقلة.';
  static const marketUnpublishFailed = 'تعذّر إلغاء نشر الوجبة.';
  static const marketRepublish = 'تحديث الوجبة المنشورة';
  static const marketPublishReview = 'راجع ما سيظهر للآخرين قبل النشر.';
  static const marketPublishFailed =
      'تعذّر نشر الوجبة. راجع بياناتها وحاول مرة أخرى.';
  static const marketAuthorFallback = 'مستخدم صحتك';
  static const marketName = 'اسم الوجبة';
  static const marketDescription = 'الوصف';
  static const marketTags = 'وسوم مفصولة بفاصلة';
  static const calories = 'سعرة';
  static const explore = 'اكتشف';
  static const account = 'حسابي';
  static const assistant = 'المساعد';
  static const assistantTitle = 'مساعد صحتك';
  static const back = 'رجوع';
  static const assistantHeadline = 'بماذا أساعدك؟';
  static const assistantEmpty =
      'اكتب ما أكلت أو اسأل عن يومك. راجع أي إضافة قبل حفظها.';
  static const assistantExampleRequest = 'أضف ١٥٠ جرام دجاج للغداء';
  static const assistantComposerHint = 'اكتب طلبك هنا…';
  static const assistantDisclosureTitle = 'قبل أول سؤال';
  static const assistantDisclosureBody =
      'عندما تسأل، نرسل إلى المساعد البيانات اللازمة للإجابة فقط، مثل هدفك وملخص يومك. تمر البيانات عبر خادم صحتك إلى xAI، ولا نحفظ محادثتك في Firestore.';
  static const assistantDisclosureConfirm = 'فهمت، ابدأ';
  static const assistantPrivacyNote = 'محادثتك تبقى على جهازك';
  static const assistantSuggestionRemaining = 'ما المتبقي من هدفي؟';
  static const assistantSuggestionToday = 'ماذا أكلت اليوم؟';
  static const assistantSuggestionProtein = 'اقترح وجبة بروتين من مكتبتي';
  static const assistantSuggestionWeek = 'كيف كان أسبوعي؟';
  static const assistantSuggestionBreakfast = 'اقترح فطورًا صحيًا';
  static const assistantSuggestionLunch = 'اقترح غداءً متوازنًا';
  static const assistantSuggestionDinner = 'اقترح عشاءً خفيفًا';
  static const assistantSuggestionGoal = 'هل أنا قريب من هدفي اليوم؟';
  static const assistantQuota = 'بلغت الحد اليومي — يمكنك المتابعة غدًا';
  static const assistantOffline = 'يحتاج المساعد إلى اتصال بالإنترنت';
  static const assistantRetry = 'حاول مجددًا';
  static const assistantModelPickerTooltip = 'اختر نموذج المساعد';
  static const assistantConfirm = 'تأكيد';
  static const assistantEdit = 'تعديل';
  static const assistantEditFoodTitle = 'راجع كمية الطعام';
  static const assistantEditFailed = 'تعذّر تعديل الاقتراح. حاول مرة أخرى.';
  static const assistantSaveEdit = 'حفظ التعديل';
  static const assistantCancel = 'إلغاء';
  static const assistantUndo = 'تراجع';
  static const assistantCancelled = 'أُلغي الاقتراح';
  static const assistantUndone = 'تم التراجع';
  static const assistantUndoExpired = 'انتهت مهلة التراجع';
  static const assistantEstimatedBadge = 'تقديري';
  static const assistantNewChat = 'محادثة جديدة';
  static const assistantHistoryTooltip = 'سجل المحادثات';
  static const assistantHistoryTitle = 'محادثاتك';
  static const assistantHistoryEmpty = 'لا توجد محادثات سابقة بعد';
  static const assistantHistoryUntitled = 'محادثة بلا عنوان';
  static const assistantHistoryDeleteTooltip = 'حذف المحادثة';
  static const assistantHeaderTourMessage =
      'جديد بالأعلى: سجل الإجراءات، سجل المحادثات، ومحادثة جديدة.';
  static const assistantHeaderTourDismiss = 'فهمت';

  // «سجل المساعد» -- the write-action audit trail (Phase 5C), distinct from
  // the chat-session history above.
  static const agentLogTooltip = 'سجل المساعد';
  static const agentLogTitle = 'سجل المساعد';
  static const agentLogEmptyTitle = 'لا توجد إجراءات بعد';
  static const agentLogEmptyMessage =
      'يسجّل المساعد هنا كل تعديل ينفّذه على يومك أو وجباتك.';
  static const agentLogFilterAll = 'الكل';
  static const agentLogFilterAdd = 'إضافة';
  static const agentLogFilterEdit = 'تعديل';
  static const agentLogFilterRemove = 'حذف';
  static const agentLogFilterSwap = 'استبدال';
  static const agentLogUndo = 'تراجع';
  static const agentLogUndone = 'تم التراجع';
  static const agentLogToday = 'اليوم';
  static const agentLogYesterday = 'أمس';
  static const comingNext = 'سيكتمل هذا القسم في الخطوة التالية';
  static const retry = 'إعادة المحاولة';
  static const newDay = 'يوم جديد';
  static const emptyDay = 'لم يُسجَّل أي شيء في هذا اليوم';
  static const protein = 'بروتين';
  static const carbs = 'كارب';
  static const fat = 'دهون';
  static const grams = 'ج';
  static const macroConsumed = 'المأكول';
  static const macroPlanned = 'المخطط';
  static const macroProgressToggle = 'التبديل بين المأكول والمخطط';
  static const mealOwnTotal = 'إجمالي هذه الوجبة';
  static const dayAfterAdding = 'اليوم المخطط لو أضفتها اليوم';
  static const dayAfterEditing = 'اليوم المخطط بعد هذا التعديل';
  static const onTarget = 'على الهدف';
  static const kcal = 'سعرة';
  static const energyBreakdownTitle = 'من أين جاء رقمك؟';
  static const energyBmr = 'معدل الحرق الأساسي (BMR)';
  static const energyBmrDetail = 'جسمك يحرقها وأنت نائم';
  static const energyTdeeDetail = 'احتراقك الكلي اليومي';
  static const energyAdjustmentDetail = 'التعديل للوصول إلى هدفك';
  static const energyTarget = 'هدفك اليومي';
  static const energyTargetDetail = 'السعرات المقترحة ليومك';
  static const energyExplanation =
      'تنقص سعراتك عن احتراقك الكلي، لا عن معدل الحرق الأساسي.';
  static const energyManualTitle = 'هدفك اليومي اليدوي';
  static String agentProposalDate(String date) => 'تاريخ التسجيل: $date';
  static const agentUnsupportedDate =
      'يمكن للمساعد تعديل سجل اليوم فقط. لم يتم تسجيل شيء في تاريخ آخر.';
  static const agentSearchIncomplete =
      'لم يُرجع البحث نتيجة مكتملة مع مصادر. حاول مرة أخرى.';
  static const energyManualDescription = 'أدخلت هذا الهدف يدويًا.';
  static String energyActivity(String activity) => '× $activity';
  static String energyWeeklyGoal(String goal, double rate) =>
      '$goal ${rate.toStringAsFixed(2)} كجم/أسبوع';
  static const goalReached = [
    'وصلت لهدفك اليوم! 🎯',
    'يوم مثالي، استمر!',
    'الحلقة اكتملت ✨',
  ];
  // --- Phase 8a agent strings ---
  static const agentToolFailed = 'تعذّر تنفيذ الأداة. حاول مرة أخرى.';
  static const agentSearchingWeb = 'أبحث في الإنترنت…';
  static const agentSearchedWeb = 'اكتمل البحث في الإنترنت';
  static const agentReadingWeight = 'أراجع سجل الوزن…';
  static const agentReadWeight = 'راجعت سجل الوزن';
  static const agentReadingTraining = 'أراجع خطة التمرين…';
  static const agentReadTraining = 'راجعت خطة التمرين';
  static const agentPreparingProposal = 'أجهّز اقتراحًا…';
  static const agentProposalReady = 'الاقتراح جاهز للتأكيد';
  static const agentSources = 'المصادر';
  static const agentWeightKg = 'الوزن بالكيلوجرام';
  static const agentSetsReps = 'المجموعات والتكرارات';
  static const agentTrainingDays = 'أيام التمرين';
  static const agentExerciseDone = 'مكتمل';
  static const agentExerciseNotDone = 'غير مكتمل';
  static const agentWebUnavailable = 'البحث في الإنترنت غير متاح الآن.';
  static const agentDataUnavailable = 'تعذّر الوصول إلى البيانات.';
  static String agentLogWeightProposal(String kg) => 'تسجيل وزن اليوم: $kg كجم';
  static String agentLoggedWeight(String kg) => 'سجّلت وزن اليوم: $kg كجم.';
  static const agentRestoreWeight = 'استعادة وزن اليوم السابق';
  static String agentExerciseProposal(bool done, String name) =>
      '${done ? 'إكمال' : 'إلغاء إكمال'} $name';
  static String agentExerciseReceipt(bool done, String name) =>
      done ? 'أكملت $name.' : 'ألغيت إكمال $name.';
  static const agentRestoreExercise = 'استعادة حالة التمرين';
  static String agentAddPlanProposal(String name) => 'إضافة $name إلى الخطة';
  static String agentAddedPlan(String name) => 'أضفت $name إلى خطة التمرين.';
  static String agentRemovePlanProposal(String name) => 'إزالة $name من الخطة';
  static const agentRemovedPlan = 'أزلت التمرين من الخطة.';
  static const agentUndo = 'تراجع';
}
