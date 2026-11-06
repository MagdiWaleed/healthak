import 'package:diet_app2/ui/components/activity_rings.dart';
import 'package:diet_app2/ui/components/check_tile.dart';
import 'package:diet_app2/ui/components/streak_chip.dart';
import 'package:diet_app2/ui/motion/motion.dart';
import 'package:diet_app2/ui/theme/app_colors.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rings expose percentages and fit at 120px', (tester) async {
    final rings = [
      const RingSpec(progress: .5, color: AppPalette.emerald, label: 'السعرات'),
      const RingSpec(progress: 1.2, color: AppPalette.coral, label: 'التمرين'),
      const RingSpec(
          progress: .75, color: AppPalette.violet, label: 'البروتين'),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home:
          Scaffold(body: Center(child: ActivityRings(rings: rings, size: 120))),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
    final semantics = tester.getSemantics(find.byType(ActivityRings));
    expect(semantics.label, contains('السعرات 50٪'));
    expect(semantics.label, contains('التمرين 120٪'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('check tile calls onChanged and describes state', (tester) async {
    bool? changed;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
          body: CheckTile(
        title: 'تمرين',
        checked: false,
        onChanged: (value) => changed = value,
      )),
    ));
    await tester.tap(find.text('تمرين'));
    expect(changed, isTrue);
    expect(
        tester.getSemantics(find.byType(CheckTile)).label, contains('تمرين'));
  });

  testWidgets('streak chip shows count and coral glow at three',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: StreakChip(count: 3)),
    ));
    expect(find.text('3'), findsOneWidget);
    expect(
        tester.getSemantics(find.byType(StreakChip)).label, contains('3 أيام'));
    final decorated =
        tester.widgetList<Container>(find.byType(Container)).where(
              (c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration! as BoxDecoration).boxShadow != null,
            );
    expect(decorated, isNotEmpty);
  });

  testWidgets('motion gate returns child under reduced motion', (tester) async {
    const child = Text('ثابت');
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Column(children: [entrance(child), pop(child)])),
      ),
    ));
    expect(find.text('ثابت'), findsNWidgets(2));
    expect(find.byType(Animate), findsNothing);
  });
}
