/// Arabic copy shared by new screens.
///
/// Legacy screens keep their original inline strings until Step 2 replaces
/// them. New work uses this file so wording does not drift across screens.
abstract final class AppStrings {
  static const appName = 'صحتك';
  static const guestMode = 'وضع الضيف';
  static const guestHeadline = 'استكشف صحتك قبل إنشاء حساب';
  static const guestDescription =
      'شاهد شكل المتابعة اليومية والوجبات. أنشئ حساباً لحفظ بياناتك ومزامنتها.';
  static const signInOrCreateAccount = 'تسجيل الدخول أو إنشاء حساب';
  static const previewOnly = 'معاينة فقط';
  static const dailyTarget = 'هدف اليوم';
  static const remaining = 'متبقي';
  static const mealIdeas = 'أفكار وجبات';
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
  static const account = 'حسابي';
  static const assistant = 'المساعد';
  static const assistantHeadline = 'أفهم يومك من بياناتك، ولا أخمّن';
  static const assistantEmpty =
      'اسألني عن طعامك وأهدافك. تعتمد إجابتي على بياناتك الصحية الفعلية.';
  static const assistantComposerHint = 'اكتب للمساعد…';
  static const assistantDisclosureTitle = 'قبل أول سؤال';
  static const assistantDisclosureBody =
      'عندما تسأل، نرسل إلى المساعد البيانات اللازمة للإجابة فقط، مثل هدفك وملخص يومك. تمر البيانات عبر خادم صحتك إلى xAI، ولا نحفظ محادثتك في Firestore.';
  static const assistantDisclosureConfirm = 'فهمت، ابدأ';
  static const assistantPrivacyNote = 'محادثتك تبقى على جهازك';
  static const assistantSuggestionRemaining = 'ما المتبقي من هدفي؟';
  static const assistantSuggestionToday = 'ماذا أكلت اليوم؟';
  static const assistantSuggestionProtein = 'اقترح وجبة بروتين من مكتبتي';
  static const assistantSuggestionWeek = 'كيف كان أسبوعي؟';
  static const assistantQuota = 'بلغت الحد اليومي — يمكنك المتابعة غدًا';
  static const assistantOffline = 'يحتاج المساعد إلى اتصال بالإنترنت';
  static const assistantRetry = 'حاول مجددًا';
  static const assistantModelPickerTooltip = 'اختر نموذج المساعد';
  static const assistantConfirm = 'تأكيد';
  static const assistantCancel = 'إلغاء';
  static const assistantUndo = 'تراجع';
  static const assistantCancelled = 'أُلغي الاقتراح';
  static const assistantUndone = 'تم التراجع';
  static const assistantEstimatedBadge = 'تقديري';
  static const assistantNewChat = 'محادثة جديدة';
  static const assistantHistoryTooltip = 'سجل المحادثات';
  static const assistantHistoryTitle = 'محادثاتك';
  static const assistantHistoryEmpty = 'لا توجد محادثات سابقة بعد';
  static const assistantHistoryUntitled = 'محادثة بلا عنوان';
  static const assistantHistoryDeleteTooltip = 'حذف المحادثة';

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
  static const energyManualDescription = 'أدخلت هذا الهدف يدويًا.';
  static String energyActivity(String activity) => '× $activity';
  static String energyWeeklyGoal(String goal, double rate) =>
      '$goal ${rate.toStringAsFixed(2)} كجم/أسبوع';
  static const goalReached = [
    'وصلت لهدفك اليوم! 🎯',
    'يوم مثالي، استمر!',
    'الحلقة اكتملت ✨',
  ];
}
