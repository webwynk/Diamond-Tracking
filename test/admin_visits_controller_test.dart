import 'dart:async';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/admin_visits_controller.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/admin_visits_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_visits.dart';

void main() {
  late FakeAdminVisitRepository repo;
  late ProviderContainer container;

  /// 45 visits, newest (id v44) first.
  List<String> ids(int n) => <String>[for (var i = n - 1; i >= 0; i--) 'v$i'];

  ProviderContainer make(FakeAdminVisitRepository fake) {
    final c = ProviderContainer(
      overrides: [adminVisitRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    // An auto-disposed controller lives only while something listens.
    c.listen(adminVisitsControllerProvider('emp-1'), (_, _) {});
    return c;
  }

  AdminVisitsState read() =>
      container.read(adminVisitsControllerProvider('emp-1'));
  AdminVisitsNotifier notifier() =>
      container.read(adminVisitsControllerProvider('emp-1').notifier);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repo = FakeAdminVisitRepository([
      for (var i = 44; i >= 0; i--) adminVisit('v$i', minute: i % 60),
    ]);
    container = make(repo);
  });

  test('starts on loading, then shows the first page', () async {
    expect(read().load, AdminVisitsLoad.loading);

    await settle();

    expect(read().load, AdminVisitsLoad.loaded);
    expect(read().visits.map((v) => v.id), ids(45).take(20));
    expect(read().hasMore, isTrue);
    expect(repo.calls.single.employeeId, 'emp-1');
    expect(repo.calls.single.afterId, isNull);
    expect(repo.calls.single.limit, 20);
  });

  test('loadMore adds the next, older page after the last visit', () async {
    await settle();

    await notifier().loadMore();

    expect(read().visits, hasLength(40));
    expect(repo.calls.last.afterId, 'v25');
    expect(read().hasMore, isTrue);

    await notifier().loadMore();

    expect(read().visits, hasLength(45));
    expect(read().hasMore, isFalse);
    expect(read().visits.map((v) => v.id).toSet(), hasLength(45));
  });

  test('loadMore does nothing when there is nothing older', () async {
    repo.all = repo.all.take(3).toList();
    container = make(repo);
    await settle();
    final calls = repo.calls.length;

    await notifier().loadMore();

    expect(read().hasMore, isFalse);
    expect(repo.calls.length, calls);
  });

  test('two loadMore calls at once ask the server once', () async {
    await settle();
    final before = repo.calls.length;

    final a = notifier().loadMore();
    final b = notifier().loadMore();
    await Future.wait(<Future<void>>[a, b]);

    expect(repo.calls.length, before + 1);
    expect(read().visits, hasLength(40));
  });

  test(
    'an older page that fails keeps the visits and offers a retry',
    () async {
      await settle();
      repo.failure = const NetworkException();

      await notifier().loadMore();

      expect(read().visits, hasLength(20));
      expect(read().loadMoreFailed, isTrue);
      expect(read().isLoadingMore, isFalse);
      expect(read().load, AdminVisitsLoad.loaded);

      repo.failure = null;
      await notifier().loadMore();

      expect(read().visits, hasLength(40));
      expect(read().loadMoreFailed, isFalse);
    },
  );

  test('a failed first load is an error, never an empty list', () async {
    repo.failure = const NetworkException();
    container = make(repo);

    await settle();

    expect(read().load, AdminVisitsLoad.failed);
    expect(read().visits, isEmpty);

    repo.failure = null;
    await notifier().refresh();

    expect(read().load, AdminVisitsLoad.loaded);
    expect(read().visits, isNotEmpty);
  });

  test('an employee with no visits is loaded and empty', () async {
    repo.all = [];
    container = make(repo);

    await settle();

    expect(read().load, AdminVisitsLoad.loaded);
    expect(read().visits, isEmpty);
    expect(read().hasMore, isFalse);
  });

  test('refresh that fails keeps what is on screen', () async {
    await settle();
    repo.failure = const ServerException();

    await notifier().refresh();

    expect(read().load, AdminVisitsLoad.loaded);
    expect(read().visits, hasLength(20));
  });

  test('refresh brings in a visit added since', () async {
    await settle();
    repo.all = [adminVisit('new', minute: 59), ...repo.all];

    await notifier().refresh();

    expect(read().visits.first.id, 'new');
  });

  test('an answer overtaken by a newer refresh is dropped', () async {
    repo.gate = Completer<void>();
    container = make(repo);
    await settle();
    final slow = repo.gate!;
    repo.gate = null;
    repo.all = [adminVisit('fresh', minute: 59)];

    await notifier().refresh();
    expect(read().visits.map((v) => v.id), <String>['fresh']);

    slow.complete();
    await settle();

    expect(read().visits.map((v) => v.id), <String>['fresh']);
  });
}
