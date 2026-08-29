import 'package:diet_app2/ui/feedback/glass_snack_bar.dart';
import 'package:diet_app2/ui/glass/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the shared glass surface with an accessible action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => GlassSnackBar.show(
                context,
                'تم الحفظ',
                tone: GlassSnackTone.success,
                actionLabel: 'تراجع',
                onAction: () {},
              ),
              child: const Text('اعرض'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('اعرض'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('تم الحفظ'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'تراجع'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
