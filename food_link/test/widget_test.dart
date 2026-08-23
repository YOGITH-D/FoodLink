import 'package:flutter_test/flutter_test.dart';

import 'package:food_link/main.dart';

void main() {
  testWidgets('App boots and renders the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FoodLinkApp());
    // Don't pumpAndSettle here: the splash screen holds a CircularProgressIndicator
    // (infinite animation) while it waits to navigate, which would hang pumpAndSettle.
    await tester.pump();

    expect(find.text('FoodLink'), findsOneWidget);
    expect(find.text('Predict, Share, Reduce Waste'), findsOneWidget);

    // Advance past the splash screen's delayed navigation so its Timer fires and
    // is cleaned up before the test tears down (otherwise the test framework
    // flags it as a leaked pending timer).
    await tester.pump(const Duration(seconds: 3));
  });
}
