import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exceptions.dart';
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
///
/// The months are IST months and "now" is the server's clock, the same as the
/// admin's attendance screen, so the two screens add up the same sessions the
/// same way. It loads every session from the start of last month (not just the
/// newest few), so last month's totals are complete.
class DutyHistoryNotifier extends Notifier<DutyHistoryState> {
  /// Sessions read per request.
  static const int _pageSize = 100;

  /// Safety cap on sessions read (two months hold a small fraction of this).
  static const int _maxSessions = 600;

  late final DutyRepository _dutyRepository;
  List<DutySession> _sessions = const <DutySession>[];

  /// The server's clock when the history was loaded (UTC).
  DateTime _serverNow = DateTime.now().toUtc();

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
      _serverNow = await _readServerNow();
      final ist = DutyTimeHelper.toIst(_serverNow);
      final windowStart = DutyTimeHelper.istDayStartUtc(
        DateTime(ist.year, ist.month - 1),
      );
      _sessions = await _loadSince(authState.profile.id, windowStart);
      _publish(state.filter);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load your duty history.',
      );
    }
  }

  /// The server's clock. If it cannot be read the history is still shown, on
  /// the phone's clock, rather than failing the whole screen.
  Future<DateTime> _readServerNow() async {
    try {
      return await _dutyRepository.getServerTime();
    } on AppException {
      return DateTime.now().toUtc();
    }
  }

  /// Every session that started on or after [start], newest first.
  Future<List<DutySession>> _loadSince(
    String employeeId,
    DateTime start,
  ) async {
    final all = <DutySession>[];
    while (true) {
      final page = await _dutyRepository.getDutyHistory(
        employeeId: employeeId,
        startDate: start,
        limit: _pageSize,
        offset: all.length,
      );
      all.addAll(page);
      if (page.length < _pageSize || all.length >= _maxSessions) return all;
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
    final ist = DutyTimeHelper.toIst(_serverNow);
    final thisMonth = DateTime(ist.year, ist.month);
    final lastMonth = DateTime(ist.year, ist.month - 1);

    // A wall-clock IST month as a UTC instant, so the label is not shifted
    // again by the phone's zone.
    String monthLabel(DateTime month) => DutyTimeHelper.formatMonthAndYear(
      DateTime.utc(month.year, month.month),
    );

    bool inMonth(DutySession s, DateTime month) {
      final ist = DutyTimeHelper.toIst(s.startedAt);
      return ist.year == month.year && ist.month == month.month;
    }

    final (List<DutySession> selected, String label) = switch (filter) {
      DutyHistoryFilter.thisMonth => (
        _sessions.where((s) => inMonth(s, thisMonth)).toList(),
        monthLabel(thisMonth),
      ),
      DutyHistoryFilter.lastMonth => (
        _sessions.where((s) => inMonth(s, lastMonth)).toList(),
        monthLabel(lastMonth),
      ),
      DutyHistoryFilter.autoEnded => (
        _sessions.where(_isAutoEnded).toList(),
        'AUTO-ENDED SHIFTS',
      ),
      DutyHistoryFilter.custom => (_sessions, 'LAST 2 MONTHS'),
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
        durationStr: DutyTimeHelper.formatElapsed(
          session.durationAt(_serverNow),
        ),
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
    var total = Duration.zero;
    var totalKm = 0.0;
    var totalVisits = 0;

    for (final s in sessions) {
      total += s.durationAt(_serverNow);
      totalKm += s.totalDistanceKm;
      totalVisits += s.visitsCount;
    }

    // Added to the second, then shown, so the total equals the sessions listed
    // (the admin's attendance screen adds them the same way).
    return DutyHistorySummary(
      periodLabel: periodLabel,
      totalDays: totalDays,
      totalHours: DutyTimeHelper.formatElapsed(total),
      totalKm: double.parse(totalKm.toStringAsFixed(1)),
      totalVisits: totalVisits,
    );
  }
}
