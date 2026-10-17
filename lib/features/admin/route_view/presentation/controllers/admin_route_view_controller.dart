import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/utils/duty_time_helper.dart';
import '../../../../../core/utils/phone_clock.dart';
import '../../../../../core/utils/route_geometry.dart';
import '../../../../../data/repositories/supabase_route_repository.dart';
import '../../../../../domain/entities/route_day.dart';
import '../../../../../domain/repositories/route_repository.dart';
import 'admin_route_view_state.dart';

/// Provider exposing the source of stored routes.
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return SupabaseRouteRepository();
});

/// Which employee, and which day to open on (null means today).
@immutable
class RouteViewArgs {
  const RouteViewArgs({required this.employeeId, this.initialDate});

  final String employeeId;

  /// An IST calendar day (only year, month and day are used).
  final DateTime? initialDate;

  @override
  bool operator ==(Object other) =>
      other is RouteViewArgs &&
      other.employeeId == employeeId &&
      other.initialDate == initialDate;

  @override
  int get hashCode => Object.hash(employeeId, initialDate);
}

/// Provider for Screen 23 Route View, one per employee and starting day.
/// Auto-disposed with the screen.
final adminRouteViewControllerProvider = NotifierProvider.autoDispose
    .family<AdminRouteViewNotifier, AdminRouteViewState, RouteViewArgs>(
      AdminRouteViewNotifier.new,
    );

/// Loads one employee's stored route for one IST day.
///
/// The picture is built from the full stored points: the line is simplified for
/// drawing only, and the totals shown come from the server, never from the
/// drawn line (docs/07 section 4). A load that is overtaken by a newer one (the
/// admin tapped through several days) is dropped, so a slow answer for an old
/// day never replaces the day on screen.
class AdminRouteViewNotifier extends Notifier<AdminRouteViewState> {
  AdminRouteViewNotifier(this.args);

  final RouteViewArgs args;

  /// Days of raw GPS points kept (PRD section 5), which bounds how far back a
  /// route can be drawn.
  static const int retentionDays = 30;

  /// How far back the date picker goes. Older days only show their totals,
  /// which are kept indefinitely.
  static const int historyDays = 365;

  int _request = 0;
  bool _stopped = false;

  DateTime _todayIst() {
    final ist = DutyTimeHelper.toIst(ref.read(phoneClockProvider)());
    return DateTime(ist.year, ist.month, ist.day);
  }

  bool _isExpired(DateTime date) =>
      date.isBefore(_todayIst().subtract(const Duration(days: retentionDays)));

  @override
  AdminRouteViewState build() {
    final initial = args.initialDate;
    final date = initial == null
        ? _todayIst()
        : DateTime(initial.year, initial.month, initial.day);
    ref.onDispose(() => _stopped = true);
    Future<void>.microtask(_load);
    return AdminRouteViewState(selectedDate: date, isExpired: _isExpired(date));
  }

  /// Loads the day again (after a failure, or to see a fresher "today").
  Future<void> reload() => _load();

  void previousDate() {
    final earliest = _todayIst().subtract(const Duration(days: historyDays));
    final previous = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day - 1,
    );
    if (previous.isBefore(earliest)) return;
    _select(previous);
  }

  void nextDate() {
    final next = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day + 1,
    );
    if (next.isAfter(_todayIst())) return;
    _select(next);
  }

  void _select(DateTime date) {
    state = AdminRouteViewState(
      selectedDate: date,
      isExpired: _isExpired(date),
    );
    _load();
  }

  Future<void> _load() async {
    if (_stopped) return;
    final ticket = ++_request;
    final date = state.selectedDate;
    final expired = state.isExpired;
    state = state.copyWith(
      load: RouteLoad.loading,
      clearError: true,
      clearDay: true,
    );

    // The IST day as a UTC interval (IST has no daylight saving).
    final startUtc = DutyTimeHelper.istDayStartUtc(date);
    final endUtc = startUtc.add(const Duration(days: 1));

    try {
      final day = await ref
          .read(routeRepositoryProvider)
          .fetchDay(
            employeeId: args.employeeId,
            dayStartUtc: startUtc,
            dayEndUtc: endUtc,
            withPoints: !expired,
          );
      if (ticket != _request || _stopped) return;
      state = _loaded(day, date);
    } on AppException catch (e) {
      if (ticket != _request || _stopped) return;
      state = state.copyWith(load: RouteLoad.failed, errorMessage: e.message);
    } catch (_) {
      if (ticket != _request || _stopped) return;
      state = state.copyWith(
        load: RouteLoad.failed,
        errorMessage: 'Could not load the route. Please try again.',
      );
    }
  }

  AdminRouteViewState _loaded(RouteDay day, DateTime date) {
    final analysis = RouteGeometry.analyse(day.points);
    final serverToday = DutyTimeHelper.toIst(day.serverNow);
    return state.copyWith(
      load: RouteLoad.loaded,
      day: day,
      analysis: analysis,
      summary: day.sessions.isEmpty ? null : RouteSummary.from(day, analysis),
      isToday:
          date ==
          DateTime(serverToday.year, serverToday.month, serverToday.day),
    );
  }
}
