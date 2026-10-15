import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_page.dart';


/// Entry point.
///
/// Phase 1: the app reads build-time configuration, validates environment,
/// initializes Supabase, and launches into the official Splash / Auth flow.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail loudly and immediately rather than launching a misconfigured app.
  Env.validate();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const ProviderScope(child: DiamondTrackingApp()));
}

/// Root widget.
class DiamondTrackingApp extends StatelessWidget {
  const DiamondTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diamond Agritech',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Light mode only, forced. The system dark setting is deliberately
      // ignored. See docs/03-DESIGN-SYSTEM.md.
      themeMode: ThemeMode.light,
      home: const SplashPage(),
    );
  }
}

