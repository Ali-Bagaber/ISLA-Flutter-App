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
class AuthGate extends StatefulWidget {
  final int initialTabIndex;

  const AuthGate({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Cache the future per uid so auth-stream re-emissions don't re-fetch.
  Future<Map<String, dynamic>>? _settingsFuture;
  String? _lastUid;

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
        final user = authSnap.data;
        if (user == null) {
          // Reset cache on sign-out so the next sign-in re-checks.
          _settingsFuture = null;
          _lastUid = null;
          return const LoginScreen();
        }

        // Only create a new Future when the uid changes (fresh login).
        if (_settingsFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _settingsFuture = UserSettingsService.loadSettings();
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _settingsFuture,
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
              // Only send truly new accounts through onboarding.
              // Existing users whose settings doc was never created get
              // auto-completed so they land on the home screen directly.
              final createdAt = user.metadata.creationTime;
              final isNewAccount = createdAt == null ||
                  DateTime.now().difference(createdAt).inMinutes < 10;

              if (!isNewAccount) {
                // Mark complete silently so this never triggers again.
                UserSettingsService.saveStudyPlan(onboardingComplete: true);
                return const MainNavigation();
              }

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
