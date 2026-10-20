import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/repositories/visit_repository.dart';
import '../utils/failure_log.dart';

/// Keeps trying to send the visits waiting on the phone while the employee app
/// is open: at once, every [interval], and each time the app comes back to the
/// front. The visits themselves are safe in the phone's database either way;
/// this only decides when to try (PRD F10, docs/08 section 6).
class VisitSyncService with WidgetsBindingObserver {
  VisitSyncService(
    this._repository, {
    this.interval = const Duration(seconds: 60),
  });

  final VisitRepository _repository;
  final Duration interval;

  Timer? _timer;

  /// Starts the periodic sending. Safe to call again.
  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  /// Stops the periodic sending. Waiting visits stay safely on the phone.
  void stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// One sending pass now. Never throws: a failure just means "next time".
  Future<void> syncNow() async {
    try {
      await _repository.syncPendingVisits();
    } on Object catch (e) {
      logFailure('VisitSyncService: pass failed', e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }
}
