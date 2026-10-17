import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_notification_repository.dart';
import 'package:diamond_tracking/domain/entities/admin_notification.dart';
import 'package:diamond_tracking/domain/repositories/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseNotificationRepository] and the real
/// Supabase client; only the network is replaced.
Map<String, Object?> _row(
  int id, {
  String type = 'duty_on',
  bool isRead = false,
  Object? details,
}) => <String, Object?>{
  'id': id,
  'type': type,
  'employee_id': 'e1',
  'session_id': 's$id',
  'details': details ?? <String, Object?>{},
  'created_at': '2026-10-17T05:00:00+00:00',
  'is_read': isRead,
};

void main() {
  late List<http.Request> requests;

  SupabaseNotificationRepository repositoryAnswering(
    http.Response Function(http.Request request) answer,
  ) {
    final supabase = MockSupabase(answer);
    requests = supabase.requests;
    return SupabaseNotificationRepository(supabase.client);
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  group('fetchPage', () {
    test(
      'asks the server for one page with the filters, plus one extra row',
      () async {
        final repository = repositoryAnswering((r) => jsonResponse(<Object>[]));

        await repository.fetchPage(
          before: 120,
          limit: 30,
          unreadOnly: true,
          types: AdminNotificationType.alertTypes,
          employeeIds: const ['e1', 'e2'],
        );

        final call = requests.single;
        expect(call.url.path, endsWith('/rpc/list_notifications'));
        final body = bodyOf(call);
        expect(body['p_before'], 120);
        expect(
          body['p_limit'],
          31,
          reason: 'one extra row says whether more exist',
        );
        expect(body['p_unread_only'], isTrue);
        expect(body['p_types'], ['mock_gps', 'battery_low', 'no_signal']);
        expect(body['p_employees'], ['e1', 'e2']);
      },
    );

    test('no filter is sent as null, not as an empty list', () async {
      final repository = repositoryAnswering((r) => jsonResponse(<Object>[]));

      await repository.fetchPage();

      final body = bodyOf(requests.single);
      expect(body['p_before'], isNull);
      expect(body['p_types'], isNull);
      expect(body['p_employees'], isNull);
      expect(body['p_unread_only'], isFalse);
    });

    test('reads the rows, with this admins read state', () async {
      final repository = repositoryAnswering(
        (r) => jsonResponse(<Object>[
          _row(9, isRead: true),
          _row(
            8,
            type: 'battery_low',
            details: <String, Object?>{'battery_level': 12},
          ),
        ]),
      );

      final page = await repository.fetchPage();

      expect(page.items.map((n) => n.id), [9, 8]);
      expect(page.items.first.isRead, isTrue);
      expect(page.items.last.isRead, isFalse);
      expect(page.items.last.type, AdminNotificationType.batteryLow);
      expect(page.items.last.details['battery_level'], 12);
      expect(page.items.last.sessionId, 's8');
      expect(page.items.first.createdAt, DateTime.utc(2026, 10, 17, 5));
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, 8);
    });

    test('one row over the limit means more exist, and is not shown', () async {
      final repository = repositoryAnswering(
        (r) =>
            jsonResponse(<Object>[for (var id = 10; id >= 6; id--) _row(id)]),
      );

      final page = await repository.fetchPage(limit: 4);

      expect(page.items.map((n) => n.id), [10, 9, 8, 7]);
      expect(page.hasMore, isTrue);
      expect(
        page.nextCursor,
        7,
        reason: 'the next page starts below the last shown',
      );
    });

    test(
      'a type this app does not know is skipped but cannot stall paging',
      () async {
        final repository = repositoryAnswering(
          (r) =>
              jsonResponse(<Object>[_row(5, type: 'geofence_enter'), _row(4)]),
        );

        final page = await repository.fetchPage(limit: 1);

        expect(page.items, isEmpty);
        expect(page.hasMore, isTrue);
        expect(
          page.nextCursor,
          5,
          reason: 'the cursor still moves past the unknown row',
        );
      },
    );

    test('a malformed row is skipped, not fatal', () async {
      final repository = repositoryAnswering(
        (r) => jsonResponse(<Object>[
          <String, Object?>{'id': 'x'},
          _row(3),
        ]),
      );

      final page = await repository.fetchPage();

      expect(page.items.map((n) => n.id), [3]);
    });

    test('an empty answer is an empty page', () async {
      final repository = repositoryAnswering((r) => jsonResponse(<Object>[]));

      final page = await repository.fetchPage();

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });
  });

  group('unread count and marking read', () {
    test('the unread count is the servers number', () async {
      final repository = repositoryAnswering((r) => jsonResponse(137));

      expect(await repository.unreadCount(), 137);
      expect(
        requests.single.url.path,
        endsWith('/rpc/unread_notification_count'),
      );
    });

    test('an unread count that arrives as text is still read', () async {
      final repository = repositoryAnswering((r) => jsonResponse('12'));

      expect(await repository.unreadCount(), 12);
    });

    test('marking read sends the ids; no ids sends nothing', () async {
      final repository = repositoryAnswering((r) => jsonResponse(2));

      await repository.markRead(const [4, 5]);
      await repository.markRead(const []);

      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        endsWith('/rpc/mark_notifications_read'),
      );
      expect(bodyOf(requests.single)['p_ids'], [4, 5]);
    });

    test('mark all read calls the server function', () async {
      final repository = repositoryAnswering((r) => jsonResponse(9));

      await repository.markAllRead();

      expect(
        requests.single.url.path,
        endsWith('/rpc/mark_all_notifications_read'),
      );
    });
  });

  group('failures', () {
    test('a lost connection is a network error', () async {
      final repository = SupabaseNotificationRepository(
        MockSupabase.offline().client,
      );

      expect(repository.fetchPage(), throwsA(isA<NetworkException>()));
    });

    test('a permission refusal is explained, not shown raw', () async {
      final repository = repositoryAnswering(
        (r) => jsonResponse(<String, Object>{
          'code': '42501',
          'message': 'permission denied for table notifications',
        }, 403),
      );

      await expectLater(
        repository.fetchPage(),
        throwsA(
          isA<UnauthorizedRoleException>().having(
            (e) => e.message,
            'message',
            isNot(contains('42501')),
          ),
        ),
      );
    });

    test('a server error never leaks database text', () async {
      final repository = repositoryAnswering(
        (r) => jsonResponse(<String, Object>{
          'code': 'XX000',
          'message': 'relation "secret" exploded',
        }, 500),
      );

      await expectLater(
        repository.unreadCount(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            isNot(contains('secret')),
          ),
        ),
      );
    });
  });

  group('watch', () {
    test(
      'a channel that cannot be opened is reported as not connected, not thrown into the zone',
      () async {
        // No injected client and Supabase is not initialised, so opening the
        // channel fails. This used to reach the zone as an uncaught error.
        final event = await SupabaseNotificationRepository()
            .watch()
            .first
            .timeout(const Duration(seconds: 2));

        expect(event, isA<NotificationConnectionChanged>());
        expect((event as NotificationConnectionChanged).connected, isFalse);
      },
    );
  });

  group('AdminNotification.tryParse', () {
    test('a Realtime insert has no read flag and is unread', () {
      final n = AdminNotification.tryParse(<String, dynamic>{
        'id': 7,
        'type': 'no_signal',
        'employee_id': 'e1',
        'session_id': null,
        'details': <String, dynamic>{'never_sent': true},
        'created_at': '2026-10-17T05:00:00+00:00',
      });

      expect(n, isNotNull);
      expect(n!.isRead, isFalse);
      expect(n.sessionId, isNull);
      expect(n.details['never_sent'], isTrue);
    });

    test('details that are not an object become empty', () {
      final n = AdminNotification.tryParse(<String, dynamic>{
        'id': 7,
        'type': 'duty_on',
        'employee_id': 'e1',
        'details': 'oops',
        'created_at': '2026-10-17T05:00:00+00:00',
      });

      expect(n!.details, isEmpty);
    });

    test('every type the database can write is known', () {
      for (final wire in const [
        'duty_on',
        'duty_off',
        'duty_auto_ended',
        'mock_gps',
        'battery_low',
        'no_signal',
      ]) {
        expect(AdminNotificationType.fromWire(wire)?.wire, wire);
      }
      expect(AdminNotificationType.fromWire('whatever'), isNull);
      expect(
        AdminNotificationType.dutyTypes.every((t) => t.isDutyEvent),
        isTrue,
      );
      expect(AdminNotificationType.alertTypes.every((t) => t.isAlert), isTrue);
    });
  });
}
