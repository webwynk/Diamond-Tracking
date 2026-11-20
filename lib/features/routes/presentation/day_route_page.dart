import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/ist_format.dart';
import '../application/route_providers.dart';
import 'day_route_view.dart';

/// A full screen for one day's route (from History, or the admin's lists).
class DayRoutePage extends ConsumerWidget {
  const DayRoutePage({required this.dayId, super.key, this.personName});

  final int dayId;

  /// Shown in the title on the admin side.
  final String? personName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? day = ref.watch(dayViewProvider(dayId)).value?.day?.day;
    final String date = day == null ? 'Route' : IstFormat.date(day);
    return Scaffold(
      appBar: AppBar(
        title: Text(personName == null ? date : '$personName · $date'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dayViewProvider(dayId)),
          ),
        ],
      ),
      body: DayRouteView(dayId: dayId),
    );
  }
}
