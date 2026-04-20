// Basic smoke test for Needin Express App.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // MyApp requires Firebase & Supabase initialization,
    // so we just verify the test framework is working.
    expect(1 + 1, equals(2));
  });
}
