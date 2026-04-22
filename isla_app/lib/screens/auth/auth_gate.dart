import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../main_navigation.dart';
import 'login_screen.dart';

/// Routes between LoginScreen and MainNavigation based on auth state.
/// Also handles the case where Firebase is not configured (goes straight to app).
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
      builder: (context, snapshot) {
        // Still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Logged in (or Firebase not configured → treat as logged in)
        if (snapshot.data != null) {
          return const MainNavigation();
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
