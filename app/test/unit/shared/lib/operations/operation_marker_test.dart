import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('operationKey', () {
    test('is a SHA-256 in hexadecimal, the same for the same operation', () {
      final key = operationKey(OperationKind.erasure, 's-lea');

      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(operationKey(OperationKind.erasure, 's-lea'), key);
    });

    test('differs by kind and by target', () {
      final erasure = operationKey(OperationKind.erasure, 'x');

      expect(operationKey(OperationKind.closure, 'x'), isNot(erasure));
      expect(operationKey(OperationKind.erasure, 'y'), isNot(erasure));
    });

    test('is salted by the club: not recomputable from the student identifier '
        'alone, the same for a second device of the same club', () {
      const lea = 's-lea';
      const club = ClubId('c1');
      final salted = operationKey(OperationKind.erasure, lea, club: club);

      expect(salted, sha256Hex('c1|erasure|s-lea'));
      expect(salted, isNot(operationKey(OperationKind.erasure, lea)));
      expect(salted, isNot(sha256Hex('erasure:s-lea')));
      expect(
        operationKey(OperationKind.erasure, lea, club: const ClubId('c2')),
        isNot(salted),
      );
      expect(operationKey(OperationKind.erasure, lea, club: club), salted);
    });

    test('does not contain the target, so it names nobody', () {
      expect(
        operationKey(OperationKind.erasure, 'lea-dupont'),
        isNot(contains('lea')),
      );
    });
  });

  group('derivedId', () {
    test('is stable, shaped like an identifier without underscore', () {
      final id = derivedId('a' * 64, 'season');

      expect(id, derivedId('a' * 64, 'season'));
      expect(
        id,
        matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
      );
      expect(id, isNot(contains('_')));
    });

    test('differs by operation and by label', () {
      final id = derivedId('a' * 64, 'season');

      expect(derivedId('b' * 64, 'season'), isNot(id));
      expect(derivedId('a' * 64, 'group:g1'), isNot(id));
    });
  });

  group('OperationKind.tryParse', () {
    test('reads the stored names and nothing else', () {
      expect(OperationKind.tryParse('erasure'), OperationKind.erasure);
      expect(OperationKind.tryParse('closure'), OperationKind.closure);
      expect(OperationKind.tryParse('import'), isNull);
      expect(OperationKind.tryParse(null), isNull);
    });
  });

  test('advanced moves the count by one and keeps the rest', () {
    final terms = ClosureTerms(
      seasonId: const SeasonId('se'),
      closedOn: DateTime(2026, 10, 12),
      prepareNext: true,
      dropPlanned: false,
    );
    final marker = OperationMarker(
      key: 'k',
      kind: OperationKind.closure,
      done: 3,
      stage: 1,
      role: Role.director,
      terms: terms,
    );

    final next = marker.advanced(nextStage: 2);

    expect(next.done, 4);
    expect(next.stage, 2);
    expect(next.key, 'k');
    expect(next.kind, OperationKind.closure);
    expect(next.role, Role.director);
    expect(next.terms, terms);
  });

  test('two equal terms are equal (a resumed closure finds the same ones)', () {
    ClosureTerms terms() => ClosureTerms(
      seasonId: const SeasonId('se'),
      closedOn: DateTime(2026, 10, 12),
      prepareNext: true,
      dropPlanned: true,
    );

    expect(terms(), terms());
  });
}
