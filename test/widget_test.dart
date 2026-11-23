import 'package:flutter_test/flutter_test.dart';
import 'package:heat/main.dart';

void main() {
  testWidgets('HeatApp renders track, movement counter, and dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HeatApp());
    await tester.pumpAndSettle();

    expect(find.text('HEAT — Deutschland'), findsOneWidget);
    expect(find.text('DÉPLACEMENT'), findsOneWidget);
    expect(find.text('1/62'), findsOneWidget);

    await tester.tap(find.text('+1 Case'));
    await tester.pumpAndSettle();

    expect(find.text('2/62'), findsOneWidget);
  });
}
