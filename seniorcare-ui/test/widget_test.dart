import 'package:flutter_test/flutter_test.dart';
import 'package:seniorcare_ui/main.dart';

void main() {
  testWidgets('App launches and shows role select', (WidgetTester tester) async {
    await tester.pumpWidget(const SeniorCareApp());
    await tester.pumpAndSettle();
    expect(find.text('SeniorCare AI'), findsOneWidget);
  });
}
