import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/features/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Artisan POS'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email and Password
    expect(find.byType(ElevatedButton), findsOneWidget); // Giriş Yap button
  });
}
