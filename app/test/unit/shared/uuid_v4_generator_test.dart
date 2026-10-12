import 'dart:math';

import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generates RFC 4122 version 4 identifiers', () {
    final ids = UuidV4Generator();

    for (var i = 0; i < 50; i++) {
      expect(ids.next(), matches(uuidV4));
    }
  });

  test('generates distinct identifiers', () {
    final ids = UuidV4Generator();

    final generated = {for (var i = 0; i < 200; i++) ids.next()};

    expect(generated, hasLength(200));
  });

  test('is deterministic for a given source of randomness', () {
    final first = UuidV4Generator.withRandom(Random(7)).next();
    final second = UuidV4Generator.withRandom(Random(7)).next();

    expect(first, second);
  });

  test('sets the version and variant bits on a zeroed source', () {
    final ids = UuidV4Generator.withRandom(_ZeroRandom());

    expect(ids.next(), '00000000-0000-4000-8000-000000000000');
  });
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
