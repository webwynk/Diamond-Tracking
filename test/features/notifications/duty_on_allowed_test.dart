import 'package:diamond_tracking/app/routes.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/presentation/home_page.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/application/push_service.dart';
import 'package:diamond_tracking/features/notifications/domain/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppNotification n(int id, String kind, {bool read = false}) =>
      AppNotification(
        id: id,
        kind: kind,
        title: 't',
        createdAt: DateTime.utc(2026, 11, 20, 6),
        readAt: read ? DateTime.utc(2026, 11, 20, 7) : null,
      );

  test('"duty on allowed" opens Home; others as before (L81)', () {
    expect(
      notificationTarget(AppRole.employee, null, kind: dutyOnAllowedKind),
      Routes.userHome,
    );
    expect(notificationTarget(AppRole.employee, 5), Routes.userRequest(5));
    expect(
      notificationTarget(AppRole.employee, null),
      Routes.userNotifications,
    );
    expect(notificationTarget(AppRole.admin, 5), Routes.adminRequest(5));
  });

  test('a tapped notification keeps its kind (L81)', () {
    const PushOpen open = PushOpen(requestId: 7, kind: 'decided');
    final PushOpen back = PushOpen.fromPayload(open.toPayload());
    expect((back.requestId, back.kind), (7, 'decided'));
    final PushOpen allowed = PushOpen.fromPayload(
      const PushOpen(kind: dutyOnAllowedKind).toPayload(),
    );
    expect((allowed.requestId, allowed.kind), (null, dutyOnAllowedKind));
    // Older notifications carried only the request id.
    expect(PushOpen.fromPayload('12').requestId, 12);
    final PushOpen data = PushOpen.fromData(<String, dynamic>{
      'request_id': '3',
      'kind': 'new_request',
    });
    expect((data.requestId, data.kind), (3, 'new_request'));
  });

  test('Home reloads once for a new "duty on allowed" (L81)', () {
    final List<AppNotification> before = <AppNotification>[n(1, 'decided')];
    expect(newDutyOnAllowed(before, before), isFalse);
    expect(
      newDutyOnAllowed(before, <AppNotification>[
        n(2, dutyOnAllowedKind),
        ...before,
      ]),
      isTrue,
    );
    final List<AppNotification> seen = <AppNotification>[
      n(2, dutyOnAllowedKind),
      ...before,
    ];
    expect(newDutyOnAllowed(seen, seen), isFalse);
    expect(
      newDutyOnAllowed(before, <AppNotification>[
        n(3, dutyOnAllowedKind, read: true),
      ]),
      isFalse,
    );
  });
}
