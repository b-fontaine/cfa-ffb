import 'package:billard_cfa/app/operation_marker_document.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const author = UserId('u-dir');
  final erasure = OperationMarker(
    key: 'a' * 64,
    kind: OperationKind.erasure,
    done: 1,
    stage: 1,
    role: Role.director,
  );
  final closure = OperationMarker(
    key: 'b' * 64,
    kind: OperationKind.closure,
    done: 2,
    stage: 3,
    role: Role.admin,
    terms: ClosureTerms(
      seasonId: const SeasonId('se1'),
      closedOn: DateTime(2026, 10, 12),
      prepareNext: true,
      dropPlanned: false,
    ),
  );

  test('creation writes the whitelist of fields, with the server dates', () {
    final fields = OperationMarkerDocument.create(erasure, createdBy: author);

    expect(fields.keys.toSet(), {
      'operationId',
      'kind',
      'done',
      'stage',
      'role',
      'createdBy',
      'startedAt',
      'updatedAt',
    });
    expect(fields['startedAt'], serverTimestamp);
    expect(fields['updatedAt'], serverTimestamp);
    expect(fields['createdBy'], 'u-dir');
  });

  test('a closure also carries its season, its day and its two choices', () {
    final fields = OperationMarkerDocument.create(closure, createdBy: author);

    expect(fields['seasonId'], 'se1');
    expect(fields['closedOn'], '2026-10-12T00:00:00.000');
    expect(fields['prepareNext'], isTrue);
    expect(fields['dropPlanned'], isFalse);
  });

  test('no field of a marker can name a student', () {
    for (final marker in [erasure, closure]) {
      final fields = OperationMarkerDocument.create(marker, createdBy: author);
      expect(
        fields.keys,
        isNot(anyOf(contains('studentId'), contains('studentIds'))),
      );
      expect(fields.keys, isNot(contains('firstName')));
    }
  });

  test('an advance changes the count, the stage and the date only', () {
    final fields = OperationMarkerDocument.advance(
      erasure.advanced(nextStage: 2),
    );

    expect(fields, {'done': 2, 'stage': 2, 'updatedAt': serverTimestamp});
  });

  test('what is written is read back', () {
    for (final marker in [erasure, closure]) {
      final stored = {
        ...OperationMarkerDocument.create(marker, createdBy: author),
        'startedAt': DateTime.utc(2026, 10, 12),
        'updatedAt': DateTime.utc(2026, 10, 12, 1),
      };

      final read = OperationMarkerDocument.decode(
        StoredDocument('clubs/c1/operations/${marker.key}_u-dir', stored),
      );

      expect(read.key, marker.key);
      expect(read.kind, marker.kind);
      expect(read.done, marker.done);
      expect(read.stage, marker.stage);
      expect(read.role, marker.role);
      expect(read.terms, marker.terms);
      expect(read.updatedAt, DateTime.utc(2026, 10, 12, 1));
    }
  });

  test('an unknown role or kind is a malformed document', () {
    final fields = {
      ...OperationMarkerDocument.create(erasure, createdBy: author),
      'kind': 'import',
    };

    expect(
      () => OperationMarkerDocument.decode(StoredDocument('p/x', fields)),
      throwsA(isA<ServiceFailure>()),
    );
  });
}
