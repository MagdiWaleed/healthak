import 'package:diet_app2/ui/glass/glass_scaffold.dart';
import 'package:diet_app2/ui/glass/specular_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route arrival makes one shared light orbit and settles',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassScaffold(
          body: SizedBox.expand(),
          lightEventKey: 0,
        ),
      ),
    );

    final scope = tester.widget<SpecularScope>(find.byType(SpecularScope));
    final resting = scope.notifier!.value;

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(scope.notifier!.value, isNot(resting));

    await tester.pump(const Duration(milliseconds: 3400));
    // A complete 360 degree sweep lands on the same physical light angle.
    expect((scope.notifier!.value - resting).abs(), closeTo(360, 0.01));
  });

  testWidgets('changing the page key replays the shared orbit', (tester) async {
    Widget app(int page) => MaterialApp(
          home: GlassScaffold(
            lightEventKey: page,
            body: const SizedBox.expand(),
          ),
        );

    await tester.pumpWidget(app(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3400));
    final scope = tester.widget<SpecularScope>(find.byType(SpecularScope));
    final settled = scope.notifier!.value;

    await tester.pumpWidget(app(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(scope.notifier!.value, isNot(settled));
  });

  testWidgets('reduced motion leaves the edge at its resting angle',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: GlassScaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final scope = tester.widget<SpecularScope>(find.byType(SpecularScope));
    final resting = scope.notifier!.value;
    await tester.pump(const Duration(milliseconds: 3400));

    expect(scope.notifier!.value, resting);
  });

  testWidgets('vertical scrolling refracts the one shared light source',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassScaffold(
          body: SingleChildScrollView(
            child: SizedBox(height: 1800),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3400));

    final scope = tester.widget<SpecularScope>(find.byType(SpecularScope));
    final before = scope.notifier!.value;
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pump();

    // 300px at 18 degrees per 100px is visibly larger than the 30-degree
    // highlight itself. The old direct 2-degree mapping moved only 6 degrees.
    expect((scope.notifier!.value - before).abs(), closeTo(54, 1));
  });
}
