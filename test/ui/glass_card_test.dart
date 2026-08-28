import 'package:diet_app2/ui/glass/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scroll-safe GlassCard contains no BackdropFilter',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: GlassCard(child: Text('meal'))));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
