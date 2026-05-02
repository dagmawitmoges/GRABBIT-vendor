import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:grabbit_vendor/features/auth/screens/login_screen.dart';
import 'package:grabbit_vendor_app/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('Login screen UI test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Check text fields
    expect(find.byType(TextField), findsNWidgets(2));

    // Check login button
    expect(find.text('Login'), findsOneWidget);

    // Enter text
    await tester.enterText(
        find.byType(TextField).at(0), 'test@email.com');
    await tester.enterText(
        find.byType(TextField).at(1), 'password123');

    // Tap button
    await tester.tap(find.text('Login'));
    await tester.pump();
  });
}