import 'package:diet_app2/ui/glass/glass_card.dart';
import 'package:diet_app2/ui/glass/specular_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('list cards can phase the shared specular light per row',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            GlassCard(child: Text('one')),
            GlassCard(specularAngleOffset: 8, child: Text('two')),
          ],
        ),
      ),
    );

    final borders =
        tester.widgetList<SpecularBorder>(find.byType(SpecularBorder)).toList();
    expect(borders.map((border) => border.angleOffsetDegrees), [0, 8]);
  });

  testWidgets('scroll-safe GlassCard contains no BackdropFilter',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: GlassCard(child: Text('meal'))));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
