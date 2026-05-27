/// Smoke test for the IslaLogo widget — renders without crashing and shows the
/// "ISLA" wordmark. This is a lightweight widget test that doesn't pull in
/// Firebase / file_picker, so it runs on any platform.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isla_app/widgets/isla_logo.dart';

void main() {
  testWidgets('IslaLogo shows the ISLA wordmark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IslaLogo(),
        ),
      ),
    );
    expect(find.text('ISLA'), findsOneWidget);
  });

  testWidgets('IslaLogo hides text when showText is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IslaLogo(showText: false),
        ),
      ),
    );
    expect(find.text('ISLA'), findsNothing);
  });
}
