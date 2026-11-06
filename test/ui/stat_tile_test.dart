import 'package:diet_app2/ui/components/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long values scale down instead of overflowing a narrow tile',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 110,
            child: StatTile(label: 'مكتمل', value: '12 / 14', unit: 'كجم'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('12 / 14'), findsOneWidget);
  });
}
