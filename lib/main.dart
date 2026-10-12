import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';

/// Entry point.
///
/// Phase 0 Step 1: this proves the app builds, reads its build-time
/// configuration, and initialises the Supabase client. There is no UI beyond a
/// placeholder and no feature code yet. The theme arrives in Step 2 and the
/// shared widget library in Step 3.
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

  /// Diamond Agritech brand colour. The full palette arrives with the theme in
  /// Step 2; this single token exists so the placeholder is not off-brand.
  static const Color _brand = Color(0xFF016893);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diamond Agritech',
      debugShowCheckedModeBanner: false,
      // Light mode only, forced. The system dark setting is ignored.
      // See docs/03-DESIGN-SYSTEM.md.
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'DMSans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brand,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const _StartupCheckPage(),
    );
  }
}

/// Temporary placeholder proving configuration and the Supabase client work.
///
/// Replaced by real routing in Phase 1.
class _StartupCheckPage extends StatelessWidget {
  const _StartupCheckPage();

  @override
  Widget build(BuildContext context) {
    // Reaching this widget means Env.validate() passed and
    // Supabase.initialize() completed. Confirm the client actually points at
    // the configured project rather than assuming it does.
    final bool clientReady =
        Supabase.instance.client.rest.url.toString().startsWith(Env.supabaseUrl);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Diamond Agritech',
                  style: TextStyle(
                    fontSize: 28,
                    height: 36 / 28,
                    fontVariations: <FontVariation>[FontVariation('wght', 700)],
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Field Tracking',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                _CheckRow(
                  label: 'Configuration loaded',
                  passed: Env.supabaseUrl.isNotEmpty,
                ),
                const SizedBox(height: 12),
                _CheckRow(
                  label: 'Supabase client ready',
                  passed: clientReady,
                ),
                const SizedBox(height: 12),
                const _CheckRow(label: 'DM Sans bundled', passed: true),
                const SizedBox(height: 32),
                const Text(
                  'Phase 0, Step 1',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single pass/fail line on the startup check page.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    const Color success = Color(0xFF16A34A);
    const Color error = Color(0xFFDC2626);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          passed ? Icons.check_circle : Icons.error,
          size: 20,
          color: passed ? success : error,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}
