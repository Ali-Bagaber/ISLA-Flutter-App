import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'config/firebase_runtime_config.dart';
import 'services/nav_controller.dart';
import 'services/notification_service.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'screens/onboarding/finalize_setup_screen.dart';
import 'screens/onboarding/select_intention_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/value_proposition_screen.dart';
import 'core/theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive must be initialised before ThemeProvider.load() reads the box.
  await Hive.initFlutter();

  if (FirebaseRuntimeConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseRuntimeConfig.options);
  }

  // On web, Firestore's IndexedDB persistence (enabled by default in SDK 11.x)
  // causes INTERNAL ASSERTION FAILED errors on the first write of a new session.
  // Disabling it forces all ops through the network and avoids that bad state.
  if (kIsWeb && Firebase.apps.isNotEmpty) {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
  }

  await NotificationService.instance.init();

  // Restore persisted theme before building the widget tree.
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  runApp(
    ProviderScope(
      child: provider_pkg.MultiProvider(
        providers: [
          provider_pkg.ChangeNotifierProvider.value(value: themeProvider),
          provider_pkg.ChangeNotifierProvider(create: (_) => NavController()),
        ],
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
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboard',
      name: 'onboard',
      builder: (context, state) => const ValuePropositionScreen(),
    ),
    GoRoute(
      path: '/onboard/value',
      name: 'valueProposition',
      builder: (context, state) => const ValuePropositionScreen(),
    ),
    GoRoute(
      path: '/onboard/intention',
      name: 'intention',
      builder: (context, state) => const SelectIntentionScreen(),
    ),
    GoRoute(
      path: '/onboard/finalize',
      name: 'onboardFinalize',
      builder: (context, state) => const FinalizeSetupScreen(),
    ),
    GoRoute(
      path: '/setup/finalize',
      name: 'finalizeSetup',
      builder: (context, state) => const FinalizeSetupScreen(),
    ),
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) => const TasksScreen(),
    ),
    GoRoute(
      path: '/analytics',
      name: 'analytics',
      builder: (context, state) => const AnalyticsScreen(),
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
