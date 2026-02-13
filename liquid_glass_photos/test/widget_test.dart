// This is a basic Flutter widget test for Liquid Glass Photos.
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_photos/main.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LiquidGlassPhotosApp());

    // Verify the app renders without errors
    expect(find.byType(LiquidGlassPhotosApp), findsOneWidget);
  });
}
