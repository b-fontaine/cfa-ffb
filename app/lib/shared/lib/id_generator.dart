import 'dart:math';

import 'package:injectable/injectable.dart';

/// Génère des identifiants uniques (injectable pour rester testable).
abstract interface class IdGenerator {
  String next();
}

/// Identifiants séquentiels lisibles : tests et scénarios BDD uniquement
/// (ils ne sont pas uniques d'un lancement à l'autre).
@LazySingleton(as: IdGenerator, env: [Environment.test])
class SequentialIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String next() => 'session-${++_counter}';
}

/// UUID version 4 (RFC 4122) en texte : identifiants persistés, uniques sans
/// coordination (futur Firebase, ADR 0001).
@LazySingleton(as: IdGenerator, env: [Environment.prod])
class UuidV4Generator implements IdGenerator {
  UuidV4Generator() : _random = Random.secure();

  /// Source d'aléa explicite, pour des tests déterministes.
  UuidV4Generator.withRandom(this._random);

  final Random _random;

  @override
  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10).join()}';
  }
}
