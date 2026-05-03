
import 'package:flutter_test/flutter_test.dart';
import 'package:coinsift_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CoinSiftApp());

    // Verify that the splash screen shows
    expect(find.text('CoinSift'), findsOneWidget);
  });
}
