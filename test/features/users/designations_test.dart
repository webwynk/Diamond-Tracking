import 'package:diamond_tracking/features/users/domain/designations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the list is the presets, then titles already in use, A to Z', () {
    expect(
      designationChoices(<String?>[null, 'Driver', 'accountant']),
      <String>[...presetDesignations, 'accountant', 'Driver'],
    );
  });

  test('a preset in another case, and repeats, are listed once', () {
    expect(
      designationChoices(<String?>['sales officer', 'Driver', 'driver ']),
      <String>[...presetDesignations, 'Driver'],
    );
  });

  test('the current value is kept in the list', () {
    expect(designationChoices(<String?>[], current: 'Cook'), contains('Cook'));
  });

  test('typed text snaps to the spelling in use', () {
    final List<String> choices = designationChoices(<String?>['Driver']);
    expect(designationSpelling('  driver ', choices), 'Driver');
    expect(designationSpelling('sales   officer', choices), 'Sales Officer');
    expect(designationSpelling('Cook  Helper', choices), 'Cook Helper');
  });
}
