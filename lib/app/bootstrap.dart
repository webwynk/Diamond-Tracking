import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/logging/app_log.dart';
import '../core/logging/error_reporter.dart';
import '../core/supabase/secure_session_storage.dart';
import '../core/supabase/supabase_time_source.dart';
import '../core/theme/app_theme.dart';
import '../core/time/clock_providers.dart';
import '../core/time/server_clock.dart';
import '../features/tracking/service/tracker_service_config.dart';
import 'app.dart';

/// Starts the app: error handlers, configuration check, Supabase, server
/// clock. Anything that fails here shows a clear startup error screen instead
/// of a half-working app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Messages from the tracker service (battery warnings) need this port.
  FlutterForegroundTask.initCommunicationPort();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLog.failure('Flutter', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.failure('Platform', error, stack);
    return true;
  };

  try {
    Env.validate();
    TrackerServiceConfig.init();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
      ),
    );

    await _installErrorReporter(Supabase.instance.client);

    final ServerClock clock = ServerClock(
      source: supabaseTimeSource(
        supabaseUrl: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
      ),
    );
    // Not awaited: the first screen must not wait on the network. Screens
    // that need a trusted time (duty on) check isSynced and sync again.
    unawaited(clock.sync());

    runApp(
      ProviderScope(
        overrides: <Override>[serverClockProvider.overrideWithValue(clock)],
        child: const DiamondApp(),
      ),
    );
  } on Object catch (error, stack) {
    AppLog.failure('Startup', error, stack);
    runApp(StartupErrorApp(error: error));
  }
}

/// From here on, errors and crashes go to the server's app errors list.
Future<void> _installErrorReporter(SupabaseClient client) async {
  String? version;
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    version = '${info.version}+${info.buildNumber}';
  } on Object catch (e, st) {
    AppLog.failure('PackageInfo', e, st);
  }
  ErrorReporter(
    isSignedIn: () => client.auth.currentSession != null,
    send: (String where, String message, DateTime at) => client.rpc<Object?>(
      'report_app_error',
      params: <String, Object?>{
        'p_where': where,
        'p_message': message,
        'p_app_version': version,
        'p_happened_at': at.toUtc().toIso8601String(),
      },
    ),
  ).install();
}

/// Shown when the app cannot start, with the reason.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'The app could not start',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
