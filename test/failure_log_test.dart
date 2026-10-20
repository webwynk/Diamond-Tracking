import 'package:diamond_tracking/core/utils/failure_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'row 42: phone +919822011334';
  const error = FormatException(secret);
  final stack = StackTrace.fromString('#0 somewhere');

  group('failureMessage', () {
    test('release: says where and the error type, never the error text', () {
      final line = failureMessage(
        'VisitRepository: could not load',
        error,
        stack,
        release: true,
      );

      expect(line, 'VisitRepository: could not load (FormatException)');
      expect(line, isNot(contains('919822011334')));
      expect(line, isNot(contains('somewhere')));
    });

    test('debug: includes the whole error and the stack trace', () {
      final line = failureMessage('Where', error, stack, release: false);

      expect(line, contains(secret));
      expect(line, contains('#0 somewhere'));
    });

    test('debug: without a stack trace there is no stray line', () {
      final line = failureMessage('Where', error, null, release: false);

      expect(line, 'Where: $error');
    });
  });

  test(
    'logFailure tells the test hook what failed, and the hook is off after',
    () {
      final seen = <String>[];
      onFailureLogged = (where, error) =>
          seen.add('$where|${error.runtimeType}');
      addTearDown(() => onFailureLogged = null);

      logFailure('Repo: could not load', const FormatException('x'));

      expect(seen, ['Repo: could not load|FormatException']);
    },
  );

  test('the test run is not a release build', () {
    expect(failureMessage('Where', error, null), contains(secret));
  });
}
