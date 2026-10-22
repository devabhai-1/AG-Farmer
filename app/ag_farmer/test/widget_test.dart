import 'package:flutter_test/flutter_test.dart';

import 'package:ag_farmer/main.dart';

void main() {
  testWidgets('AgFarmerApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const AgFarmerApp());
    await tester.pump();
    expect(find.byType(AgFarmerApp), findsOneWidget);
  });
}
