import 'package:diet_app2/page/home/home_controller.dart';
import 'package:diet_app2/page/home/home_shell.dart'
    show HomeShell, HomeShellKeys;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('add button uses the scaffold snackbar', (tester) async {
    Get.put(HomeController());
    await tester.pumpWidget(const GetMaterialApp(home: HomeShell()));
    // Settles the Today tab's staggered row entrances. Repeating animations
    // (the aurora, the FAB's press state) never settle by design, so this is
    // a bounded pump rather than pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(HomeShellKeys.quickAddFab));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
