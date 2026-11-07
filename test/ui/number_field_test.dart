import 'package:diet_app2/ui/components/number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('focus selects the prefilled value and typing replaces it',
      (tester) async {
    final controller = TextEditingController(text: '100');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NumberField(
      controller: controller,
      min: 1,
      max: 5000,
      decoration: const InputDecoration(labelText: 'غرامات'),
    ))));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(controller.selection.start, 0);
    expect(controller.selection.end, 3);
    tester.testTextInput.enterText('250');
    await tester.pump();
    expect(controller.text, '250');
  });
}
