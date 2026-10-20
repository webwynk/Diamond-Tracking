/// Result object returned by [PinValidator] giving granular status on each rule.
class PinValidationResult {
  /// Whether the PIN has exactly 6 digits.
  final bool hasSixDigits;

  /// Whether the PIN does not consist of a single repeated digit (e.g. 111111).
  final bool isNotRepeated;

  /// Whether the PIN is not an obvious sequential sequence (e.g. 123456 or 654321).
  final bool isNotSequential;

  /// Whether the confirmation PIN matches the primary PIN.
  final bool matchesConfirmation;

  const PinValidationResult({
    required this.hasSixDigits,
    required this.isNotRepeated,
    required this.isNotSequential,
    required this.matchesConfirmation,
  });

  /// True when all rules pass and the confirmation matches.
  bool get isValid =>
      hasSixDigits && isNotRepeated && isNotSequential && matchesConfirmation;
}

/// Enforces the business rules for 6-digit PINs per PRD F1 and Screen 04 design.
class PinValidator {
  const PinValidator._();

  static final RegExp _numericPattern = RegExp(r'^\d{6}$');

  /// Validates both the candidate PIN and its confirmation.
  static PinValidationResult validate(String pin, String confirmPin) {
    return PinValidationResult(
      hasSixDigits: hasSixDigits(pin),
      isNotRepeated: isNotRepeated(pin),
      isNotSequential: isNotSequential(pin),
      matchesConfirmation: pin.isNotEmpty && pin == confirmPin,
    );
  }

  /// Rule 1: Exactly 6 numeric digits.
  static bool hasSixDigits(String pin) {
    return _numericPattern.hasMatch(pin);
  }

  /// Rule 2: Not the same digit repeated 6 times (e.g. 000000, 111111).
  static bool isNotRepeated(String pin) {
    if (pin.length < 2) return true;
    final first = pin[0];
    for (int i = 1; i < pin.length; i++) {
      if (pin[i] != first) return true;
    }
    return false; // All characters matched the first
  }

  /// Rule 3: Not a sequential sequence like 123456 or 654321.
  static bool isNotSequential(String pin) {
    if (pin.length < 3) return true;

    // Check ascending sequence (e.g. 123456, 012345, 456789)
    bool isAscending = true;
    for (int i = 0; i < pin.length - 1; i++) {
      final current = int.tryParse(pin[i]);
      final next = int.tryParse(pin[i + 1]);
      if (current == null || next == null || next != (current + 1) % 10) {
        isAscending = false;
        break;
      }
    }
    if (isAscending) return false;

    // Check descending sequence (e.g. 654321, 543210, 987654)
    bool isDescending = true;
    for (int i = 0; i < pin.length - 1; i++) {
      final current = int.tryParse(pin[i]);
      final next = int.tryParse(pin[i + 1]);
      if (current == null || next == null || next != (current - 1 + 10) % 10) {
        isDescending = false;
        break;
      }
    }
    if (isDescending) return false;

    return true;
  }
}
