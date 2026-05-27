import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/user_settings_service.dart';
import '../main_navigation.dart';
import 'login_screen.dart';

/// Routes between LoginScreen, the onboarding flow, and MainNavigation
/// based on auth state and whether the user has completed onboarding.
///
/// Flow:
///   1. Auth state still loading → spinner
///   2. Not signed in → LoginScreen
///   3. Signed in + onboardingComplete is false (new account, first run)
///      → push to /onboard/intention so they go through goal + personalize
///   4. Signed in + onboardingComplete is true → MainNavigation
class AuthGate extends StatelessWidget {
  final int initialTabIndex;

  const AuthGate({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authSnap.data == null) {
          return const LoginScreen();
        }

        // Signed in — check onboarding state once. We use FutureBuilder
        // (not Stream) so this only runs at gate entry, not on every doc edit.
        return FutureBuilder<Map<String, dynamic>>(
          future: UserSettingsService.loadSettings(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final plan = (snap.data?['studyPlan'] as Map?)
                    ?.cast<String, dynamic>() ??
                const {};
            final done = plan['onboardingComplete'] == true;
            if (!done) {
              // Defer the navigation until after this frame so we don't
              // navigate during build().
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.goNamed('intention');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return const MainNavigation();
          },
        );
      },
    );
  }
}
