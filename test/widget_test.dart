import 'package:flutter_test/flutter_test.dart';

import 'package:garten_bewaesserung/main.dart';

void main() {
  testWidgets('App boots and shows the home screen title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GardenWateringApp());
    await tester.pump();

    expect(find.text('Garden Watering'), findsOneWidget);
  });
}
