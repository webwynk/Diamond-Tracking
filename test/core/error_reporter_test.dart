import 'package:diamond_tracking/core/logging/app_log.dart';
import 'package:diamond_tracking/core/logging/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(String, String)> sent;
  late bool signedIn;
  late ErrorReporter reporter;

  setUp(() {
    sent = <(String, String)>[];
    signedIn = true;
    reporter = ErrorReporter(
      isSignedIn: () => signedIn,
      send: (String where, String message, DateTime _) async =>
          sent.add((where, message)),
    );
  });
  tearDown(() => AppLog.reporter = null);

  test('AppLog.failure sends through the installed reporter (L88)', () async {
    reporter.install();
    AppLog.failure('DutyHome.refresh', StateError('server said no'));
    await Future<void>.delayed(Duration.zero);
    expect(sent, <(String, String)>[
      ('DutyHome.refresh', 'Bad state: server said no'),
    ]);
  });

  test('personal details are taken out of the message', () {
    final String out = ErrorReporter.clean(
      'Failed for rahul@diamondagritech.com at 22.572645, 88.363892 '
      'phone 9876543210 user 3f2b8c1e-1a2b-4c3d-9e8f-0a1b2c3d4e5f '
      'url https://x.supabase.co/rest/v1/visits?token=abc\nnext line',
    );
    expect(out, isNot(contains('rahul')));
    expect(out, isNot(contains('572645')));
    expect(out, isNot(contains('9876543210')));
    expect(out, isNot(contains('3f2b8c1e')));
    expect(out, isNot(contains('supabase.co')));
    expect(out, isNot(contains('\n')));
    expect(out, contains('[email]'));
    expect(out, contains('[number]'));
    expect(out, contains('[link]'));
  });

  test('long messages are cut', () {
    expect(
      ErrorReporter.clean('a ' * 400).length,
      ErrorReporter.maxMessageLength,
    );
  });

  test('each different error goes once, at most 20 a run', () async {
    await reporter.report('A', 'same');
    await reporter.report('A', 'same');
    expect(sent, hasLength(1));
    for (var i = 0; i < 30; i++) {
      await reporter.report('B', 'error $i');
    }
    expect(sent, hasLength(ErrorReporter.maxPerRun));
  });

  test('nothing is sent when nobody is signed in', () async {
    signedIn = false;
    await reporter.report('A', 'x');
    expect(sent, isEmpty);
    signedIn = true;
    await reporter.report('A', 'x');
    expect(sent, hasLength(1));
  });

  test('a failed send is dropped without reporting itself', () async {
    var calls = 0;
    final ErrorReporter failing = ErrorReporter(
      isSignedIn: () => true,
      send: (String _, String _, DateTime _) async {
        calls++;
        throw Exception('offline');
      },
    )..install();
    final List<String> logged = <String>[];
    AppLog.onFailure = (String where, Object _) => logged.add(where);
    addTearDown(() => AppLog.onFailure = null);
    AppLog.failure('Home', 'boom');
    await Future<void>.delayed(Duration.zero);
    await failing.report('Other', 'x');
    expect(calls, 2);
    expect(logged, <String>['Home']);
  });
}
