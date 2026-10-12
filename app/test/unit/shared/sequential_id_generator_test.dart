import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates distinct sequential identifiers', () {
    final ids = SequentialIdGenerator();

    expect(ids.next(), 'session-1');
    expect(ids.next(), 'session-2');
  });
}
