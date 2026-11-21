import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/config/env.dart';
import '../../../core/logging/app_log.dart';

/// Phone push notifications. A tap on one opens the app at its request.
abstract interface class PushService {
  /// Sets up and asks for the notification permission. False when push is
  /// not available (no Firebase configuration, or it failed to start).
  Future<bool> start();

  Future<String?> token();

  Stream<String> get tokenRefresh;

  /// A tapped notification: the request it names (if any) and its kind.
  Stream<PushOpen> get opened;
}

/// What a tapped notification is about.
class PushOpen {
  const PushOpen({this.requestId, this.kind});

  factory PushOpen.fromData(Map<String, dynamic> data) => PushOpen(
    requestId: int.tryParse(data['request_id']?.toString() ?? ''),
    kind: data['kind']?.toString(),
  );

  /// Reads [toPayload]; a plain number (older notifications) is a request id.
  factory PushOpen.fromPayload(String? payload) {
    final String p = payload ?? '';
    final int bar = p.indexOf('|');
    if (bar < 0) return PushOpen(requestId: int.tryParse(p));
    final String kind = p.substring(0, bar);
    return PushOpen(
      requestId: int.tryParse(p.substring(bar + 1)),
      kind: kind.isEmpty ? null : kind,
    );
  }

  final int? requestId;
  final String? kind;

  /// "kind|request id", kept with a notification shown by the app.
  String toPayload() => '${kind ?? ''}|${requestId ?? ''}';
}

/// Push is not set up: notifications show inside the app only.
class NoPushService implements PushService {
  const NoPushService();

  @override
  Future<bool> start() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream<String>.empty();

  @override
  Stream<PushOpen> get opened => const Stream<PushOpen>.empty();
}

/// The channel Firebase posts to (named in the push function's message).
const AndroidNotificationChannel requestsChannel = AndroidNotificationChannel(
  'requests',
  'Requests and decisions',
  description: 'New requests for the admin, and decisions on your requests',
  importance: Importance.high,
);

class FirebasePushService implements PushService {
  final StreamController<PushOpen> _opened =
      StreamController<PushOpen>.broadcast();
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  Future<bool>? _started;

  @override
  Future<bool> start() => _started ??= _start();

  Future<bool> _start() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: Env.firebaseApiKey,
            appId: Env.firebaseAppId,
            messagingSenderId: Env.firebaseSenderId,
            projectId: Env.firebaseProjectId,
          ),
        );
      }
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse r) =>
            _opened.add(PushOpen.fromPayload(r.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(requestsChannel);

      final FirebaseMessaging fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      // While the app is open Android does not show the push itself.
      FirebaseMessaging.onMessage.listen(_showInApp);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage m) => _opened.add(PushOpen.fromData(m.data)),
      );
      final RemoteMessage? initial = await fm.getInitialMessage();
      if (initial != null) {
        // After the listeners of [opened] are attached.
        scheduleMicrotask(() => _opened.add(PushOpen.fromData(initial.data)));
      }
      return true;
    } on Object catch (e, s) {
      AppLog.failure('push start', e, s);
      return false;
    }
  }

  Future<void> _showInApp(RemoteMessage m) async {
    final RemoteNotification? n = m.notification;
    if (n == null) return;
    await _local.show(
      id: m.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      payload: PushOpen.fromData(m.data).toPayload(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          requestsChannel.id,
          requestsChannel.name,
          channelDescription: requestsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  Future<String?> token() async {
    if (!await start()) return null;
    try {
      // The classic FCM token: what the push function's HTTP v1 send takes.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } on Object catch (e, s) {
      AppLog.failure('push token', e, s);
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => Firebase.apps.isEmpty
      ? const Stream<String>.empty()
      // ignore: deprecated_member_use
      : FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushOpen> get opened => _opened.stream;
}
