import 'dart:math';

import '../../auth/domain/credentials.dart';

/// A random 6-digit temporary PIN that passes [pinProblem].
String generateTempPin([Random? random]) {
  final Random r = random ?? Random.secure();
  while (true) {
    final String pin = List<String>.generate(
      6,
      (_) => '${r.nextInt(10)}',
    ).join();
    if (pinProblem(pin) == null) return pin;
  }
}
