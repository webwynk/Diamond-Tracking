import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/duty_time_helper.dart';
import '../../../../domain/entities/duty_session.dart';
import '../../../../domain/repositories/duty_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_state.dart';
import '../../../duty/presentation/controllers/duty_controller.dart';
import 'duty_history_state.dart';

/// Provider for [DutyHistoryNotifier].
final dutyHistoryControllerProvider =
    NotifierProvider<DutyHistoryNotifier, DutyHistoryState>(
      DutyHistoryNotifier.new,
    );

/// Controller governing employee duty history queries, period summaries,
/// and filter state for Screen 12.
///
/// Everything shown comes from the employee's own recorded sessions. When there
/// are none the screen is empty, and when loading fails it says so: it never
/// substitutes sample records.
class DutyHistoryNotifier extends Notifier<DutyHistoryState> {
  late final DutyRepository _dutyRepository;
  List<DutySession> _sessions = const <DutySession>[];

  @override
  DutyHistoryState build() {
    _dutyRepository = ref.watch(dutyRepositoryProvider);

    // Initial load
    Future.microtask(loadHistory);

    return DutyHistoryState(
      isLoading: true,
      summary: DutyHistorySummary(
        periodLabel: DutyTimeHelper.formatMonthAndYear(DateTime.now()),
      ),
    );
  }

  /// Fetches the signed-in employee's recorded sessions.
  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);

    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) {
      _sessions = const <DutySession>[];
      _publish(state.filter);
      return;
    }

    try {
      _sessions = await _dutyRepository.getDutyHistory(
        employeeId: authState.profile.id,
      );
      _publish(state.filter);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load your duty history.',
      );
    }
  }

  /// Switches the active filter tab and recalculates the visible list and
  /// summary from the loaded sessions.
  void setFilter(DutyHistoryFilter filter) {
    if (state.filter == filter) return;
    _publish(filter);
  }

  /// Applies [filter] to the loaded sessions and publishes list and summary.
  void _publish(DutyHistoryFilter filter) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    bool inMonth(DutySession s, DateTime month) {
      final ist = DutyTimeHelper.toIst(s.startedAt);
      return ist.year == month.year && ist.month == month.month;
    }

    final (List<DutySession> selected, String label) = switch (filter) {
      DutyHistoryFilter.thisMonth => (
        _sessions.where((s) => inMonth(s, thisMonth)).toList(),
        DutyTimeHelper.formatMonthAndYear(thisMonth),
      ),
      DutyHistoryFilter.lastMonth => (
        _sessions.where((s) => inMonth(s, lastMonth)).toList(),
        DutyTimeHelper.formatMonthAndYear(lastMonth),
      ),
      DutyHistoryFilter.autoEnded => (
        _sessions.where(_isAutoEnded).toList(),
        'AUTO-ENDED SHIFTS',
      ),
      DutyHistoryFilter.custom => (_sessions, 'ALL SHIFTS'),
    };

    state = state.copyWith(
      isLoading: false,
      filter: filter,
      items: _mapSessionsToItems(selected),
      summary: _computeSummary(selected, label),
    );
  }

  bool _isAutoEnded(DutySession session) =>
      session.endReason == 'auto_curfew' ||
      session.status == DutySessionStatus.autoCurfew;

  List<DutyHistoryItem> _mapSessionsToItems(List<DutySession> sessions) {
    return sessions.map((session) {
      final chipType = _isAutoEnded(session)
          ? DutyHistoryChipType.autoEnded
          : (session.mockPointsCount > 0
                ? DutyHistoryChipType.flagged
                : DutyHistoryChipType.none);

      return DutyHistoryItem(
        id: session.id,
        date: session.startedAt,
        dateTitle: DutyTimeHelper.formatDayAndDate(session.startedAt),
        chipType: chipType,
        flagCount: session.mockPointsCount,
        dutyTimeStr: DutyTimeHelper.formatTimeRange(
          session.startedAt,
          session.endedAt,
        ),
        durationStr: DutyTimeHelper.formatElapsed(session.elapsedDuration),
        distanceStr: session.formattedDistanceKm,
        visitsStr: '${session.visitsCount} visits',
        rawSession: session,
      );
    }).toList();
  }

  DutyHistorySummary _computeSummary(
    List<DutySession> sessions,
    String periodLabel,
  ) {
    if (sessions.isEmpty) {
      return DutyHistorySummary(periodLabel: periodLabel);
    }

    final totalDays = sessions.length;
    var totalMinutes = 0;
    var totalKm = 0.0;
    var totalVisits = 0;

    for (final s in sessions) {
      totalMinutes += s.elapsedDuration.inMinutes;
      totalKm += s.totalDistanceKm;
      totalVisits += s.visitsCount;
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return DutyHistorySummary(
      periodLabel: periodLabel,
      totalDays: totalDays,
      totalHours: '${hours}h ${minutes}m',
      totalKm: double.parse(totalKm.toStringAsFixed(1)),
      totalVisits: totalVisits,
    );
  }
}
