import 'package:diamond_tracking/features/auth/domain/pin_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinValidator tests', () {
    test('Rule 1: requires exactly 6 numeric digits', () {
      expect(PinValidator.hasSixDigits('12345'), isFalse);
      expect(PinValidator.hasSixDigits('1234567'), isFalse);
      expect(PinValidator.hasSixDigits('12345a'), isFalse);
      expect(PinValidator.hasSixDigits('abcdef'), isFalse);
      expect(PinValidator.hasSixDigits(''), isFalse);
      expect(PinValidator.hasSixDigits('492815'), isTrue);
    });

    test('Rule 2: rejects identical repeated digits', () {
      expect(PinValidator.isNotRepeated('000000'), isFalse);
      expect(PinValidator.isNotRepeated('111111'), isFalse);
      expect(PinValidator.isNotRepeated('999999'), isFalse);
      expect(PinValidator.isNotRepeated('111112'), isTrue);
      expect(PinValidator.isNotRepeated('492815'), isTrue);
    });

    test('Rule 3: rejects sequential ascending and descending digits', () {
      expect(PinValidator.isNotSequential('123456'), isFalse);
      expect(PinValidator.isNotSequential('012345'), isFalse);
      expect(PinValidator.isNotSequential('456789'), isFalse);
      expect(PinValidator.isNotSequential('654321'), isFalse);
      expect(PinValidator.isNotSequential('543210'), isFalse);
      expect(PinValidator.isNotSequential('987654'), isFalse);

      expect(PinValidator.isNotSequential('123450'), isTrue);
      expect(PinValidator.isNotSequential('492815'), isTrue);
      expect(PinValidator.isNotSequential('852963'), isTrue);
    });

    test('Full validate: checks all rules and confirmation matching', () {
      final invalidSequence = PinValidator.validate('123456', '123456');
      expect(invalidSequence.hasSixDigits, isTrue);
      expect(invalidSequence.isNotRepeated, isTrue);
      expect(invalidSequence.isNotSequential, isFalse);
      expect(invalidSequence.matchesConfirmation, isTrue);
      expect(invalidSequence.isValid, isFalse);

      final invalidRepeated = PinValidator.validate('777777', '777777');
      expect(invalidRepeated.hasSixDigits, isTrue);
      expect(invalidRepeated.isNotRepeated, isFalse);
      expect(invalidRepeated.isValid, isFalse);

      final mismatch = PinValidator.validate('492815', '492816');
      expect(mismatch.matchesConfirmation, isFalse);
      expect(mismatch.isValid, isFalse);

      final valid = PinValidator.validate('492815', '492815');
      expect(valid.matchesConfirmation, isTrue);
      expect(valid.isValid, isTrue);
    });
  });
}
