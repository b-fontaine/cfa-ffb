import 'package:billard_cfa/shared/lib/unique_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a free name as it is', () {
    expect(firstFreeName('Jeunes', (_) => false), 'Jeunes');
  });

  test('suffixes with 2 when the name is taken', () {
    expect(firstFreeName('Jeunes', (c) => c == 'Jeunes'), 'Jeunes (2)');
  });

  test('goes on until a free number', () {
    final taken = {'Jeunes', 'Jeunes (2)', 'Jeunes (3)'};
    expect(firstFreeName('Jeunes', taken.contains), 'Jeunes (4)');
  });
}
