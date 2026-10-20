import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/services/visit_sync_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_visit_repository.dart';

/// Counts the sending passes the service asks for.
class _CountingRepository extends LocalVisitRepository {
  int passes = 0;
  bool failing = false;

  @override
  Future<void> syncPendingVisits() async {
    passes++;
    if (failing) throw const ServerException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start sends at once, then on every interval', () async {
    final repository = _CountingRepository();
    final service = VisitSyncService(
      repository,
      interval: const Duration(milliseconds: 40),
    )..start();
    addTearDown(service.stop);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(repository.passes, greaterThanOrEqualTo(3));
  });

  test('stop ends the passes', () async {
    final repository = _CountingRepository();
    final service = VisitSyncService(
      repository,
      interval: const Duration(milliseconds: 20),
    )..start();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    service.stop();
    final passesAtStop = repository.passes;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(repository.passes, passesAtStop);
  });

  test('start twice does not start a second timer', () async {
    final repository = _CountingRepository();
    final service = VisitSyncService(
      repository,
      interval: const Duration(hours: 1),
    )..start();
    addTearDown(service.stop);
    service.start();
    await Future<void>.delayed(Duration.zero);

    expect(repository.passes, 1);
  });

  test('coming back to the front sends again', () async {
    final repository = _CountingRepository();
    final service = VisitSyncService(
      repository,
      interval: const Duration(hours: 1),
    );

    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(repository.passes, 0);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(repository.passes, 1);
  });

  test('a failing pass never throws out of the service', () async {
    final repository = _CountingRepository()..failing = true;
    final service = VisitSyncService(repository);

    await service.syncNow();

    expect(repository.passes, 1);
  });
}
