import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recording implements UnitOfWork {
  _Recording(this.name, this.log);

  final String name;
  final List<String> log;

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    log.add('$name:begin');
    try {
      final result = await body();
      log.add('$name:commit');
      return result;
    } catch (_) {
      log.add('$name:rollback');
      rethrow;
    }
  }
}

void main() {
  test('the inner unit commits before the outer one', () async {
    final log = <String>[];
    final unit = CompositeUnitOfWork(
      outer: _Recording('drift', log),
      inner: _Recording('firestore', log),
    );

    final result = await unit.run(() async {
      log.add('body');
      return 7;
    });

    expect(result, 7);
    expect(log, [
      'drift:begin',
      'firestore:begin',
      'body',
      'firestore:commit',
      'drift:commit',
    ]);
  });

  test('a failing inner commit rolls the outer one back', () async {
    final log = <String>[];
    final unit = CompositeUnitOfWork(
      outer: _Recording('drift', log),
      inner: _Recording('firestore', log),
    );

    await expectLater(
      unit.run<void>(() async => throw StateError('boom')),
      throwsStateError,
    );

    expect(log, [
      'drift:begin',
      'firestore:begin',
      'firestore:rollback',
      'drift:rollback',
    ]);
  });
}
