import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/notifications/application/notifications_providers.dart';
import 'router.dart';

class DiamondApp extends ConsumerWidget {
  const DiamondApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    // Registers the phone for push after sign-in; opens tapped notifications.
    ref.watch(pushRegistrarProvider);
    return MaterialApp.router(
      title: 'Diamond Agritech',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Light only: used outdoors in sunlight (see AppTheme).
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
