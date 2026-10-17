import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/entities/admin_notification.dart';
import 'package:diamond_tracking/domain/repositories/notification_repository.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_controller.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/controllers/admin_notification_controller.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/controllers/admin_notification_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';

/// Containers a scenario started; disposed when it ends. The framework checks
/// for running timers BEFORE tear-down callbacks run, so `addTearDown` is too
/// late for a controller that owns a periodic timer.
final List<ProviderContainer> opened = <ProviderContainer>[];

void scenario(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final container in opened) {
        container.dispose();
      }
      opened.clear();
    }
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeNotificationRepository server;
  late FakeEmployeeRepository roster;

  setUp(() {
    server = FakeNotificationRepository();
    roster = FakeEmployeeRepository(
      roster: [
        rosterEmployee('e-asha', 'Asha Patil', 'DA-101'),
        rosterEmployee('e-ravi', 'Ravi Kumar', 'DA-102'),
        rosterEmployee('e-meena', 'Meena Joshi', 'DA-103'),
      ],
    );
  });

  /// [count] notifications, ids 1..count, newest = highest id.
  void fill(int count, {String employeeId = 'e-asha'}) {
    server.all = [
      for (var id = count; id >= 1; id--)
        notification(
          id,
          employeeId: employeeId,
          ago: Duration(minutes: count - id),
        ),
    ];
  }

  Future<ProviderContainer> start(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        notificationOverride(server),
        employeeRepositoryProvider.overrideWithValue(roster),
      ],
    );
    opened.add(container);
    container.listen(adminNotificationControllerProvider, (_, _) {});
    await settle(tester);
    return container;
  }

  AdminNotificationState stateOf(ProviderContainer c) =>
      c.read(adminNotificationControllerProvider);

  AdminNotificationNotifier notifierOf(ProviderContainer c) =>
      c.read(adminNotificationControllerProvider.notifier);

  group('first load', () {
    scenario('shows loading, never an empty "all caught up"', (tester) async {
      final container = ProviderContainer(
        overrides: [
          notificationOverride(server),
          employeeRepositoryProvider.overrideWithValue(roster),
        ],
      );
      opened.add(container);
      container.listen(adminNotificationControllerProvider, (_, _) {});

      final before = stateOf(container);
      expect(before.isLoading, isTrue);
      expect(before.items, isEmpty);
      expect(before.errorMessage, isNull);
      expect(before.unreadCount, 0);
      await settle(tester);
    });

    scenario(
      'loads the first page, and the unread count is the SERVER number',
      (tester) async {
        fill(120);
        final container = await start(tester);

        final state = stateOf(container);
        expect(state.isLoading, isFalse);
        expect(state.items, hasLength(30), reason: 'one page, not everything');
        expect(state.items.first.id, 120, reason: 'newest first');
        expect(state.hasMore, isTrue);
        expect(
          state.unreadCount,
          120,
          reason: 'counted by the server, not from the 30 loaded',
        );
      },
    );

    scenario('asks for the unread filter first', (tester) async {
      fill(3);
      await start(tester);

      final call = server.pageCalls.first;
      expect(call.unreadOnly, isTrue);
      expect(call.types, isNull);
      expect(call.employeeIds, isNull);
      expect(call.limit, 30);
      expect(call.before, isNull);
    });

    scenario('knows the employees by name from the roster', (tester) async {
      fill(1);
      final container = await start(tester);

      expect(stateOf(container).names['e-asha']?.name, 'Asha Patil');
      expect(stateOf(container).names['e-asha']?.code, 'DA-101');
    });

    scenario('a failed first load is an error that reload recovers from', (
      tester,
    ) async {
      server.pageError = const NetworkException();
      final container = await start(tester);

      expect(stateOf(container).isLoading, isFalse);
      expect(stateOf(container).errorMessage, isNotNull);
      expect(stateOf(container).items, isEmpty);

      server.pageError = null;
      fill(2);
      await notifierOf(container).reload();

      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).items, hasLength(2));
    });

    scenario('a failed count does not hide the list', (tester) async {
      fill(2);
      server.countError = const NetworkException();
      final container = await start(tester);

      expect(stateOf(container).items, hasLength(2));
      expect(stateOf(container).errorMessage, isNull);
    });
  });

  group('filters are applied by the server', () {
    scenario('duty and alerts send their types; all sends none', (
      tester,
    ) async {
      fill(3);
      final container = await start(tester);
      final notifier = notifierOf(container);

      notifier.setFilter(AdminNotificationFilter.duty);
      await settle(tester);
      expect(server.pageCalls.last.types, AdminNotificationType.dutyTypes);
      expect(server.pageCalls.last.unreadOnly, isFalse);

      notifier.setFilter(AdminNotificationFilter.alerts);
      await settle(tester);
      expect(server.pageCalls.last.types, AdminNotificationType.alertTypes);

      notifier.setFilter(AdminNotificationFilter.all);
      await settle(tester);
      expect(server.pageCalls.last.types, isNull);
      expect(server.pageCalls.last.unreadOnly, isFalse);
    });

    scenario('choosing the same filter again does not reload', (tester) async {
      fill(3);
      final container = await start(tester);
      final calls = server.pageCalls.length;

      notifierOf(container).setFilter(AdminNotificationFilter.unread);
      await settle(tester);

      expect(server.pageCalls.length, calls);
    });

    scenario('the list is cleared while a new filter loads, never mixed', (
      tester,
    ) async {
      server.all = [
        notification(2, type: AdminNotificationType.mockGps),
        notification(1, type: AdminNotificationType.dutyOn),
      ];
      final container = await start(tester);
      expect(stateOf(container).items, hasLength(2));

      server.gateCall(server.pageCalls.length + 1);
      notifierOf(container).setFilter(AdminNotificationFilter.alerts);
      await tester.pump();

      expect(stateOf(container).isLoading, isTrue);
      expect(stateOf(container).items, isEmpty);

      server.release(server.pageCalls.length);
      await settle(tester);
      expect(stateOf(container).items.map((n) => n.id), [2]);
    });

    scenario('typing an employee asks for their ids, after a short pause', (
      tester,
    ) async {
      server.all = [
        notification(3, employeeId: 'e-meena'),
        notification(2, employeeId: 'e-ravi'),
        notification(1, employeeId: 'e-asha'),
      ];
      final container = await start(tester);
      final calls = server.pageCalls.length;

      notifierOf(container).setEmployeeQuery('ra');
      expect(
        stateOf(container).employeeQuery,
        'ra',
        reason: 'the field updates at once',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(server.pageCalls.length, calls, reason: 'still typing');

      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      // "ra" is in Ravi Kumar only (Asha Patil has no "ra", Meena Joshi neither).
      expect(server.pageCalls.last.employeeIds, ['e-ravi']);
      expect(stateOf(container).items.map((n) => n.id), [2]);
    });

    scenario('the code matches too, and several matches are all sent', (
      tester,
    ) async {
      fill(1);
      final container = await start(tester);

      notifierOf(container).setEmployeeQuery('da-10');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      expect(server.pageCalls.last.employeeIds, [
        'e-asha',
        'e-ravi',
        'e-meena',
      ]);
    });

    scenario(
      'text that matches nobody asks the server nothing and shows nothing',
      (tester) async {
        fill(3);
        final container = await start(tester);
        final calls = server.pageCalls.length;

        notifierOf(container).setEmployeeQuery('zzz');
        await tester.pump(const Duration(milliseconds: 400));
        await settle(tester);

        expect(server.pageCalls.length, calls);
        expect(stateOf(container).items, isEmpty);
        expect(stateOf(container).isLoading, isFalse);
        expect(stateOf(container).hasActiveEmployeeQuery, isTrue);
      },
    );

    scenario('clearing the text brings everyone back', (tester) async {
      fill(3);
      final container = await start(tester);
      notifierOf(container).setEmployeeQuery('zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      notifierOf(container).setEmployeeQuery('');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      expect(server.pageCalls.last.employeeIds, isNull);
      expect(stateOf(container).items, hasLength(3));
    });
  });

  group('older notifications', () {
    scenario('load more appends the next page below the last one', (
      tester,
    ) async {
      fill(75);
      final container = await start(tester);
      expect(stateOf(container).items, hasLength(30));

      await notifierOf(container).loadMore();
      expect(
        server.pageCalls.last.before,
        46,
        reason: 'below the oldest shown',
      );
      expect(stateOf(container).items, hasLength(60));
      expect(stateOf(container).items.last.id, 16);
      expect(stateOf(container).hasMore, isTrue);

      await notifierOf(container).loadMore();
      expect(stateOf(container).items, hasLength(75));
      expect(stateOf(container).hasMore, isFalse);

      final calls = server.pageCalls.length;
      await notifierOf(container).loadMore();
      expect(server.pageCalls.length, calls, reason: 'nothing more to ask for');
    });

    scenario('a notification already shown is not added twice', (tester) async {
      fill(40);
      final container = await start(tester);
      // A new one arrives while the admin is scrolling: ids shift under paging.
      server.all = [notification(41), ...server.all];

      await notifierOf(container).loadMore();

      final ids = stateOf(container).items.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    scenario('a failed page says so and can be tried again', (tester) async {
      fill(75);
      final container = await start(tester);

      server.pageError = const NetworkException();
      await notifierOf(container).loadMore();
      expect(stateOf(container).loadMoreFailed, isTrue);
      expect(stateOf(container).isLoadingMore, isFalse);
      expect(
        stateOf(container).items,
        hasLength(30),
        reason: 'what was shown stays',
      );

      server.pageError = null;
      await notifierOf(container).loadMore();
      expect(stateOf(container).loadMoreFailed, isFalse);
      expect(stateOf(container).items, hasLength(60));
    });

    scenario('a page that arrives after the filter changed is dropped', (
      tester,
    ) async {
      fill(75);
      final container = await start(tester);
      server.gateCall(server.pageCalls.length + 1);
      final slow = notifierOf(container).loadMore();
      await tester.pump();

      notifierOf(container).setFilter(AdminNotificationFilter.all);
      await settle(tester);
      final afterChange = stateOf(container).items.map((n) => n.id).toList();

      server.release(2);
      await slow;
      await settle(tester);

      expect(stateOf(container).items.map((n) => n.id).toList(), afterChange);
    });
  });

  group('refreshing while scrolled down', () {
    scenario('a quiet refresh keeps the older pages already loaded', (
      tester,
    ) async {
      fill(75);
      final container = await start(tester);
      await notifierOf(container).loadMore();
      expect(stateOf(container).items, hasLength(60));

      server.all = [notification(76), ...server.all];
      await notifierOf(container).refresh();

      final ids = stateOf(container).items.map((n) => n.id).toList();
      expect(ids.first, 76, reason: 'the new one is at the top');
      expect(
        ids,
        hasLength(61),
        reason: 'and nothing the admin scrolled to vanished',
      );
      expect(ids.toSet().length, ids.length);
      expect(ids, [...ids]..sort((a, b) => b.compareTo(a)));
      // Paging carries on from the deepest page, not from the top.
      await notifierOf(container).loadMore();
      expect(server.pageCalls.last.before, 16);
    });

    scenario(
      'a refresh while only the first page is shown simply replaces it',
      (tester) async {
        fill(10);
        final container = await start(tester);

        server.all = [notification(11), ...server.all];
        await notifierOf(container).refresh();

        expect(stateOf(container).items, hasLength(11));
      },
    );

    scenario('changing the filter always starts again from the first page', (
      tester,
    ) async {
      fill(75);
      final container = await start(tester);
      await notifierOf(container).loadMore();

      notifierOf(container).setFilter(AdminNotificationFilter.all);
      await settle(tester);

      expect(stateOf(container).items, hasLength(30));
    });

    scenario(
      'a refresh that overtakes "load older" does not leave the spinner on',
      (tester) async {
        fill(75);
        final container = await start(tester);
        server.gateCall(server.pageCalls.length + 1);
        final slow = notifierOf(container).loadMore();
        await tester.pump();
        expect(stateOf(container).isLoadingMore, isTrue);

        await notifierOf(container).refresh();
        server.release(2);
        await slow;
        await settle(tester);

        expect(stateOf(container).isLoadingMore, isFalse);
      },
    );

    scenario('and the same when the refresh that overtakes it fails', (
      tester,
    ) async {
      fill(75);
      final container = await start(tester);
      server.gateCall(server.pageCalls.length + 1);
      final slow = notifierOf(container).loadMore();
      await tester.pump();

      server.pageError = const NetworkException();
      await notifierOf(container).refresh();
      server.release(2);
      await slow;
      await settle(tester);

      expect(stateOf(container).isLoadingMore, isFalse);
      expect(
        stateOf(container).loadMoreFailed,
        isFalse,
        reason: 'it was overtaken, not failed',
      );
      expect(stateOf(container).refreshFailed, isTrue);
      expect(stateOf(container).items, hasLength(30));
    });
  });

  group('marking read', () {
    scenario('one: instant, the count drops, the server is told', (
      tester,
    ) async {
      fill(3);
      final container = await start(tester);
      expect(stateOf(container).unreadCount, 3);

      final future = notifierOf(container).markRead(2);
      expect(
        stateOf(container).items.firstWhere((n) => n.id == 2).isRead,
        isTrue,
      );
      expect(stateOf(container).unreadCount, 2);
      await future;

      expect(server.markReadCalls, [
        [2],
      ]);
    });

    scenario('marking it again changes nothing and asks the server nothing', (
      tester,
    ) async {
      fill(3);
      final container = await start(tester);
      await notifierOf(container).markRead(2);
      await notifierOf(container).markRead(2);

      expect(server.markReadCalls, hasLength(1));
      expect(stateOf(container).unreadCount, 2);
    });

    scenario('an unknown id is ignored', (tester) async {
      fill(3);
      final container = await start(tester);

      await notifierOf(container).markRead(999);

      expect(server.markReadCalls, isEmpty);
      expect(stateOf(container).unreadCount, 3);
    });

    scenario('undone, with a message, if the server refuses', (tester) async {
      fill(3);
      final container = await start(tester);
      server.markError = const NetworkException();

      await notifierOf(container).markRead(2);

      expect(
        stateOf(container).items.firstWhere((n) => n.id == 2).isRead,
        isFalse,
      );
      expect(stateOf(container).unreadCount, 3);
      expect(stateOf(container).actionError, isNotNull);

      notifierOf(container).clearActionError();
      expect(stateOf(container).actionError, isNull);
    });

    scenario('all: zero at once, then the list matches the server', (
      tester,
    ) async {
      fill(40);
      final container = await start(tester);

      final future = notifierOf(container).markAllRead();
      expect(stateOf(container).unreadCount, 0);
      expect(stateOf(container).items.every((n) => n.isRead), isTrue);
      await future;
      await settle(tester);

      expect(server.markAllCalls, 1);
      expect(stateOf(container).unreadCount, 0);
      expect(
        stateOf(container).items,
        isEmpty,
        reason: 'the unread list is now empty, as on the server',
      );
    });

    scenario('all, refused: the server count comes back and a message shows', (
      tester,
    ) async {
      fill(5);
      final container = await start(tester);
      server.markError = const NetworkException();

      await notifierOf(container).markAllRead();
      await settle(tester);

      expect(stateOf(container).actionError, isNotNull);
      expect(
        stateOf(container).unreadCount,
        5,
        reason: 'nothing was really read',
      );
      expect(stateOf(container).items, hasLength(5));
    });
  });

  group('live', () {
    scenario('a new notification appears at the top and raises the count', (
      tester,
    ) async {
      fill(3);
      final container = await start(tester);

      server.emit(NotificationArrived(notification(4, employeeId: 'e-ravi')));

      expect(stateOf(container).items.first.id, 4);
      expect(stateOf(container).unreadCount, 4);
    });

    scenario('the same one twice is counted once', (tester) async {
      fill(3);
      final container = await start(tester);

      server.emit(NotificationArrived(notification(4)));
      server.emit(NotificationArrived(notification(4)));

      expect(stateOf(container).items.where((n) => n.id == 4), hasLength(1));
      expect(stateOf(container).unreadCount, 4);
    });

    scenario('one the filter would hide counts on the bell but is not listed', (
      tester,
    ) async {
      server.all = [notification(1, type: AdminNotificationType.mockGps)];
      final container = await start(tester);
      notifierOf(container).setFilter(AdminNotificationFilter.duty);
      await settle(tester);
      expect(stateOf(container).items, isEmpty);
      final before = stateOf(container).unreadCount;

      server.emit(
        NotificationArrived(
          notification(2, type: AdminNotificationType.batteryLow),
        ),
      );

      expect(stateOf(container).items, isEmpty);
      expect(stateOf(container).unreadCount, before + 1);

      server.emit(NotificationArrived(notification(3)));
      expect(stateOf(container).items.map((n) => n.id), [3]);
    });

    scenario('an employee search keeps out other peoples notifications', (
      tester,
    ) async {
      fill(1);
      final container = await start(tester);
      notifierOf(container).setEmployeeQuery('ravi');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      server.emit(NotificationArrived(notification(5, employeeId: 'e-asha')));
      expect(stateOf(container).items, isEmpty);

      server.emit(NotificationArrived(notification(6, employeeId: 'e-ravi')));
      expect(stateOf(container).items.map((n) => n.id), [6]);
    });

    scenario('the connection coming back reads the list again', (tester) async {
      fill(2);
      final container = await start(tester);
      final calls = server.pageCalls.length;

      server.all = [notification(3), ...server.all];
      server.emit(const NotificationConnectionChanged(connected: true));
      await settle(tester);

      expect(server.pageCalls.length, calls + 1);
      expect(stateOf(container).items.first.id, 3);
      expect(stateOf(container).unreadCount, 3);
    });

    scenario('a lost connection alone changes nothing', (tester) async {
      fill(2);
      final container = await start(tester);
      final calls = server.pageCalls.length;

      server.emit(const NotificationConnectionChanged(connected: false));
      await settle(tester);

      expect(server.pageCalls.length, calls);
      expect(stateOf(container).items, hasLength(2));
    });

    scenario('every minute the list and the count are read again', (
      tester,
    ) async {
      fill(2);
      final container = await start(tester);
      final calls = server.pageCalls.length;

      server.all = [notification(3), ...server.all];
      await tester.pump(const Duration(minutes: 1));
      await settle(tester);

      expect(server.pageCalls.length, calls + 1);
      expect(stateOf(container).items.first.id, 3);
    });

    scenario('a failed refresh keeps what is shown and says it may be old', (
      tester,
    ) async {
      fill(2);
      final container = await start(tester);

      server.pageError = const NetworkException();
      await tester.pump(const Duration(minutes: 1));
      await settle(tester);

      expect(stateOf(container).items, hasLength(2));
      expect(stateOf(container).errorMessage, isNull);
      expect(stateOf(container).refreshFailed, isTrue);

      server.pageError = null;
      await notifierOf(container).refresh();
      expect(stateOf(container).refreshFailed, isFalse);
    });
  });

  group('names', () {
    scenario('a person created after the roster was read is learned once', (
      tester,
    ) async {
      fill(1);
      final container = await start(tester);
      final rosterCalls = roster.calls.where((c) => c == 'getEmployees').length;

      roster.roster = [
        ...roster.roster,
        rosterEmployee('e-new', 'Nita Rao', 'DA-104'),
      ];
      server.emit(NotificationArrived(notification(2, employeeId: 'e-new')));
      await settle(tester);

      expect(stateOf(container).names['e-new']?.name, 'Nita Rao');
      expect(
        roster.calls.where((c) => c == 'getEmployees').length,
        rosterCalls + 1,
      );
    });

    scenario('someone the roster never learns is not asked about forever', (
      tester,
    ) async {
      fill(1);
      final container = await start(tester);

      server.emit(NotificationArrived(notification(2, employeeId: 'e-ghost')));
      await settle(tester);
      final after = roster.calls.length;
      server.emit(NotificationArrived(notification(3, employeeId: 'e-ghost')));
      await settle(tester);

      expect(roster.calls.length, after);
      expect(stateOf(container).names.containsKey('e-ghost'), isFalse);
    });

    scenario('a roster that cannot be read still shows the list', (
      tester,
    ) async {
      roster.error = const NetworkException();
      fill(2);
      final container = await start(tester);

      expect(stateOf(container).items, hasLength(2));
      expect(stateOf(container).names, isEmpty);
    });
  });

  group('sign-out', () {
    scenario(
      'closing the screen closes the live connection and stops the timers',
      (tester) async {
        fill(2);
        final container = ProviderContainer(
          overrides: [
            notificationOverride(server),
            employeeRepositoryProvider.overrideWithValue(roster),
          ],
        );
        opened.add(container);
        final subscription = container.listen(
          adminNotificationControllerProvider,
          (_, _) {},
        );
        await settle(tester);
        expect(server.listening, isTrue);

        subscription.close();
        await tester.pump(const Duration(milliseconds: 100));
        final calls = server.pageCalls.length;
        await tester.pump(const Duration(minutes: 3));

        expect(server.pageCalls.length, calls);
      },
    );
  });
}
