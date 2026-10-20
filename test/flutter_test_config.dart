import 'dart:async';

import 'package:diamond_tracking/core/utils/failure_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs once around every test file.
///
/// A test must never reach the real Supabase client: it is not initialised in
/// tests, the repository catches the resulting assertion and the screen shows
/// an empty state, so the test passes while it is not checking what it thinks
/// it is checking. This guard turns that silent mistake into a failure that
/// names the repository, so the test gets a fake (test/support) instead.
///
/// A test that deliberately checks what happens when the client is missing
/// (for example "a channel that cannot be opened") calls [expectStrayClient].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final strays = <String>[];

  setUp(() {
    strays.clear();
    _allowed = false;
    onFailureLogged = (String where, Object error) {
      if (error.toString().contains('initialize the supabase instance')) {
        strays.add(where);
      }
    };
  });

  tearDown(() {
    onFailureLogged = null;
    final found = strays.toSet().toList();
    strays.clear();
    if (found.isNotEmpty && !_allowed) {
      fail(
        'This test reached the real Supabase client, which is not set up in '
        'tests. Give it a fake repository (test/support) or a MockSupabase '
        'client.\n  ${found.join('\n  ')}',
      );
    }
  });

  await testMain();
}

bool _allowed = false;

/// Call at the start of a test that deliberately runs without a Supabase
/// client, so the guard does not count it as a mistake.
void expectStrayClient() => _allowed = true;
