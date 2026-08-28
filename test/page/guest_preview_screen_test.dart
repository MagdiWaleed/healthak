import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/guest/guest_preview_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('shows a read-only guest preview with an authentication action',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: GuestPreviewScreen()));

    expect(find.text(AppStrings.guestMode), findsOneWidget);
    expect(find.text(AppStrings.guestHeadline), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text(AppStrings.signInOrCreateAccount), 120);
    expect(find.text(AppStrings.signInOrCreateAccount), findsOneWidget);
    await tester.scrollUntilVisible(find.text(AppStrings.accountNeeded), 80);
    expect(find.text(AppStrings.accountNeeded), findsOneWidget);
  });
}
