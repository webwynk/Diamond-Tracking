import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/services/secure_session_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_page.dart';

/// Entry point.
///
/// Phase 1: the app reads build-time configuration, validates environment,
/// initializes Supabase, and launches into the official Splash / Auth flow.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log Flutter framework errors without aborting
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exception}\n${details.stack}');
  };

  // Intercept unhandled asynchronous platform errors so the app process does not close
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Platform dispatcher error: $error\n$stack');
    return true;
  };

  // Graceful fallback if any individual widget subtree throws during build
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'A component failed to render.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    // Fail loudly and immediately rather than launching a misconfigured app.
    Env.validate();

    // Lets the background tracking service send updates to the screens.
    FlutterForegroundTask.initCommunicationPort();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        // The session is kept encrypted, not in plain preferences.
        localStorage: SecureSessionStorage(supabaseUrl: Env.supabaseUrl),
      ),
    );

    runApp(const ProviderScope(child: DiamondTrackingApp()));
  } catch (error, stack) {
    debugPrint('Startup error: $error\n$stack');
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Startup Failed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
