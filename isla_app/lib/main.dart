import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'config/firebase_runtime_config.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/isla/analytics_page.dart';
import 'screens/isla/focus_timer_page.dart';
import 'screens/isla/home_page.dart';
import 'screens/isla/tasks_page.dart';
import 'screens/onboarding/finalize_setup_page.dart';
import 'screens/onboarding/select_intention_page.dart';
import 'screens/onboarding/splash_page.dart';
import 'screens/onboarding/value_proposition_page.dart';
import 'core/theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (FirebaseRuntimeConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseRuntimeConfig.options);
  }

  runApp(
    ProviderScope(
      child: provider_pkg.ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const IslaApp(),
      ),
    ),
  );
}

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/onboard',
      name: 'onboard',
      builder: (context, state) => const ValuePropositionPage(),
    ),
    GoRoute(
      path: '/onboard/value',
      name: 'valueProposition',
      builder: (context, state) => const ValuePropositionPage(),
    ),
    GoRoute(
      path: '/onboard/intention',
      name: 'intention',
      builder: (context, state) => const SelectIntentionPage(),
    ),
    GoRoute(
      path: '/onboard/finalize',
      name: 'onboardFinalize',
      builder: (context, state) => const FinalizeSetupPage(),
    ),
    GoRoute(
      path: '/setup/finalize',
      name: 'finalizeSetup',
      builder: (context, state) => const FinalizeSetupPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/session/focus',
      name: 'focus',
      builder: (context, state) => const FocusTimerPage(),
    ),
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) => const TasksPage(),
    ),
    GoRoute(
      path: '/analytics',
      name: 'analytics',
      builder: (context, state) => const AnalyticsPage(),
    ),
    GoRoute(
      path: '/app',
      name: 'app',
      builder: (context, state) => const AuthGate(),
    ),
  ],
);

class IslaApp extends StatelessWidget {
  const IslaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = provider_pkg.Provider.of<ThemeProvider>(context).isDarkMode;

    return MaterialApp.router(
      title: 'ISLA - Study Assistant',
      debugShowCheckedModeBanner: false,
      theme: IslaTheme.light,
      darkTheme: IslaTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
