import 'dart:convert';
import 'dart:io';

import 'package:billard_cfa/entities/exercise_catalog/data/catalogue_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_sheet_fixtures.dart';
import 'repository_harness.dart';

/// Le vrai catalogue de l'application, lu depuis l'asset sur disque.
final _catalogue = _DiskCatalogue();

class _DiskCatalogue implements CatalogueRepository {
  @override
  Future<ExerciseCatalogue> load() async => parseCatalogue(
    File('assets/catalogue/catalogue-entrainement.yaml').readAsStringSync(),
  );
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 10, 12, 8);
}

ExportBackup _export(RepositoryHarness r) => ExportBackup(
  r.seasons,
  r.students,
  r.groups,
  r.sessionRecords,
  r.attempts,
  r.assessments,
  r.sessions,
  BackupCodec(),
  _FixedClock(),
);

ImportBackup _import(RepositoryHarness r) => ImportBackup(
  r.seasons,
  r.students,
  r.groups,
  r.sessionRecords,
  r.attempts,
  r.assessments,
  r.sessions,
  BackupCodec(),
  BackupRules(
    _catalogue,
    FixtureSessionSheetRepository(catalogueFixture()),
    RulesConfig(),
    _FixedClock(),
  ),
  r.unitOfWork,
);

Future<String> _exported(RepositoryHarness r) async =>
    switch (await _export(r)()) {
      Ok(:final value) => value,
      Err(:final failure) => fail('export refusé : $failure'),
    };

Future<ImportSummary> _imported(RepositoryHarness r, String content) async =>
    switch (await _import(r)(content)) {
      Ok(:final value) => value,
      Err(:final failure) => fail('import refusé : $failure'),
    };

Future<InvariantCode> _refused(RepositoryHarness r, String content) async =>
    switch (await _import(r)(content)) {
      Ok(:final value) => fail('import accepté : $value'),
      Err(failure: InvariantViolation(:final code)) => code,
      Err(:final failure) => fail('mauvais échec : $failure'),
    };

/// Un club complet : une saison, deux élèves (dont un changé de public), un
/// groupe, deux séances, trois passages, un bilan et une séance planifiée.
Future<void> _seed(RepositoryHarness r) async {
  await r.seasons.save(
    Season(
      id: const SeasonId('season'),
      label: '2026-2027',
      startDate: DateTime(2026, 9),
      endDate: DateTime(2027, 6, 30),
    ),
  );
  await r.students.save(
    Student.enroll(
      id: const StudentId('s1'),
      firstName: 'Léa',
      audience: Audience.children,
      since: DateTime(2026, 9),
    ).changeAudience(Audience.adults, DateTime(2027, 2)),
  );
  await r.students.save(
    Student.enroll(
      id: const StudentId('s2'),
      firstName: 'Théo',
      audience: Audience.children,
      since: DateTime(2026, 9),
    ),
  );
  await r.groups.save(
    Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('season'),
          name: 'Jeunes',
          audience: Audience.children,
        )
        .admit(
          studentId: const StudentId('s1'),
          studentAudience: Audience.children,
          from: DateTime(2026, 9),
        )
        .admit(
          studentId: const StudentId('s2'),
          studentAudience: Audience.children,
          from: DateTime(2026, 9),
        ),
  );
  for (final (id, day) in [('x1', 3), ('x2', 10)]) {
    await r.sessionRecords.save(
      SessionRecord(
        id: SessionId(id),
        groupId: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        date: DateTime(2026, 10, day),
        audience: Audience.children,
        present: {const StudentId('s1'), const StudentId('s2')},
        mainBlockId: 'puissance',
        sheetId: id == 'x2' ? SheetId('demi-bille-1') : null,
      ),
    );
  }
  for (final (id, student, session, passIndex) in [
    ('a1', 's1', 'x1', 1),
    ('a2', 's1', 'x1', 2),
    ('a3', 's2', 'x2', 1),
  ]) {
    await r.attempts.add(
      ExerciseAttempt(
        id: AttemptId(id),
        studentId: StudentId(student),
        sessionId: SessionId(session),
        exercise: ExerciseRef(blockId: 'puissance', number: 1),
        date: DateTime(2026, 10, 3),
        passIndex: passIndex,
        potted: 4,
        total: 5,
      ),
    );
  }
  await r.assessments.add(
    MaturityAssessment(
      id: const AssessmentId('b1'),
      studentId: const StudentId('s1'),
      date: DateTime(2026, 10, 5),
      concentration: 3,
      endurance: 2,
      frustration: 4,
      comment: 'Concentré, supporte mal l’échec',
    ),
  );
  await r.sessions.add(
    Session(
      id: 'p1',
      title: 'Rebond',
      date: DateTime(2026, 10, 12),
      audience: Audience.children,
      groupId: const GroupId('g1'),
    ),
  );
  await r.sessions.add(
    Session(
      id: 'p2',
      title: 'Demi-bille',
      date: DateTime(2026, 10, 19),
      audience: Audience.adults,
      sheetId: SheetId('demi-bille-2'),
    ),
  );
}

Map<String, Object?> _parse(String content) =>
    jsonDecode(content) as Map<String, Object?>;

List<Object?> _list(Map<String, Object?> document, String key) =>
    (document['data']! as Map<String, Object?>)[key]! as List<Object?>;

Map<String, Object?> _first(Map<String, Object?> document, String key) =>
    _list(document, key).first! as Map<String, Object?>;

/// Suite d'export/import exécutée contre chaque implémentation de repository :
/// aller-retour, idempotence, fusion et refus sans écriture partielle.
void backupContract(String label, Future<RepositoryHarness> Function() open) {
  group('$label : sauvegarde JSON', () {
    late RepositoryHarness source;
    late RepositoryHarness target;
    late String backup;

    setUp(() async {
      source = await open();
      target = await open();
      await _seed(source);
      backup = await _exported(source);
    });
    tearDown(() async {
      await source.close();
      await target.close();
    });

    Future<void> expectEmpty(RepositoryHarness r) async {
      expect(await r.students.all(), isEmpty);
      expect(await r.seasons.all(), isEmpty);
      expect(await r.groups.all(), isEmpty);
      expect(await r.sessionRecords.all(), isEmpty);
      expect(await r.attempts.all(), isEmpty);
      expect(await r.assessments.all(), isEmpty);
      expect(await r.sessions.getAll(), isEmpty);
    }

    test('declares its own format version', () {
      final document = _parse(backup);

      expect(document['format'], 'billard-cfa-backup');
      expect(document['schemaVersion'], BackupCodec.currentVersion);
      expect(document['exportedAt'], '2026-10-12T08:00:00.000Z');
    });

    test('round-trips: importing then exporting gives the same file', () async {
      final summary = await _imported(target, backup);

      expect(await _exported(target), backup);
      expect(
        summary,
        const ImportSummary(
          seasons: 1,
          students: 2,
          groups: 1,
          sessionRecords: 2,
          attempts: 3,
          assessments: 1,
          plannedSessions: 2,
        ),
      );
    });

    test('keeps the catalogue session of a planned session', () async {
      await _imported(target, backup);

      final sessions = await target.sessions.getAll();
      expect(sessions.map((s) => s.sheetId?.value), [null, 'demi-bille-2']);
      final document = _parse(backup);
      expect(
        _list(document, 'plannedSessions').map((s) => (s! as Map)['sheetId']),
        [null, 'demi-bille-2'],
      );
    });

    test('is idempotent: importing twice changes nothing', () async {
      await _imported(target, backup);
      await _imported(target, backup);

      expect(await _exported(target), backup);
      expect(await target.attempts.all(), hasLength(3));
    });

    test('merges into existing data and replaces by id', () async {
      await target.students.save(
        Student.enroll(
          id: const StudentId('s1'),
          firstName: 'Ancien prénom',
          audience: Audience.children,
          since: DateTime(2025, 9),
        ),
      );
      await target.students.save(
        Student.enroll(
          id: const StudentId('other'),
          firstName: 'Zoé',
          audience: Audience.children,
          since: DateTime(2025, 9),
        ),
      );

      await _imported(target, backup);

      final names = (await target.students.all()).map((s) => s.firstName);
      expect(names, unorderedEquals(['Léa', 'Théo', 'Zoé']));
    });

    test('exports nothing that was deleted', () async {
      await source.attempts.delete(const AttemptId('a1'));
      await source.students.delete(const StudentId('s2'));

      final document = _parse(await _exported(source));

      expect(_list(document, 'attempts'), hasLength(2));
      expect(_list(document, 'students'), hasLength(1));
    });

    test('exports and imports an empty club', () async {
      final empty = await _exported(target);

      final summary = await _imported(source, empty);

      expect(summary.students, 0);
      expect(_list(_parse(empty), 'students'), isEmpty);
    });

    group('refuses without writing anything', () {
      test('a file that is not JSON', () async {
        expect(
          await _refused(target, 'pas du json {'),
          InvariantCode.backupUnreadable,
        );
        await expectEmpty(target);
      });

      test('a JSON file that is not a backup', () async {
        expect(
          await _refused(target, '{"hello": "world"}'),
          InvariantCode.backupUnreadable,
        );
        expect(
          await _refused(target, '[1, 2]'),
          InvariantCode.backupUnreadable,
        );
        await expectEmpty(target);
      });

      for (final version in <Object?>[0, 2, 99, '1', null]) {
        test('an unsupported schemaVersion ($version)', () async {
          final document = _parse(backup)..['schemaVersion'] = version;

          expect(
            await _refused(target, jsonEncode(document)),
            InvariantCode.backupVersionUnsupported,
          );
          await expectEmpty(target);
        });
      }

      final invalidMutations = <String, void Function(Map<String, Object?>)>{
        'a passed ball count above the total': (d) =>
            _first(d, 'attempts')['potted'] = 9,
        'a blank first name': (d) => _first(d, 'students')['firstName'] = ' ',
        'an unknown audience': (d) =>
            _first(d, 'groups')['audience'] = 'seniors',
        'a malformed date': (d) => _first(d, 'seasons')['startDate'] = 'hier',
        'a number where text is expected': (d) =>
            _first(d, 'seasons')['id'] = 7,
        'a missing field': (d) => _first(d, 'assessments').remove('studentId'),
        'a season ending before it starts': (d) =>
            _first(d, 'seasons')['endDate'] = '2020-01-01T00:00:00.000',
        'an empty audience history': (d) =>
            _first(d, 'students')['audienceHistory'] = <Object?>[],
        'a missing data section': (d) => d.remove('data'),
        'more passes than allowed in one session': (d) => _list(
          d,
          'attempts',
        ).add({..._first(d, 'attempts'), 'id': 'a4', 'passIndex': 3}),
        'the same pass index twice': (d) =>
            (_list(d, 'attempts')[1]! as Map<String, Object?>)['passIndex'] = 1,
        'a session outside its season': (d) =>
            _first(d, 'sessionRecords')['date'] = '2020-01-01T00:00:00.000',
        'a session whose audience differs from its group': (d) =>
            _first(d, 'sessionRecords')['audience'] = 'adults',
        'an assessment dated in the future': (d) =>
            _first(d, 'assessments')['date'] = '2027-05-01T00:00:00.000',
        'a sheet identifier that is not text': (d) =>
            _first(d, 'plannedSessions')['sheetId'] = 7,
        'a malformed sheet identifier': (d) =>
            _first(d, 'plannedSessions')['sheetId'] = 'Pas un slug',
        'a comment that is not text': (d) =>
            _first(d, 'assessments')['comment'] = 7,
        'a comment longer than the maximum': (d) =>
            _first(d, 'assessments')['comment'] =
                'x' * (MaturityAssessment.maxCommentLength + 1),
      };
      for (final MapEntry(key: name, value: mutate)
          in invalidMutations.entries) {
        test('invalid data: $name', () async {
          final document = _parse(backup);
          mutate(document);

          expect(
            await _refused(target, jsonEncode(document)),
            InvariantCode.backupInvalid,
          );
          await expectEmpty(target);
        });
      }

      final inconsistentMutations =
          <String, void Function(Map<String, Object?>)>{
            'a duplicated season id': (d) =>
                _list(d, 'seasons').add(_first(d, 'seasons')),
            'a duplicated student id': (d) =>
                _list(d, 'students').add(_first(d, 'students')),
            'a duplicated group id': (d) =>
                _list(d, 'groups').add(_first(d, 'groups')),
            'a duplicated session id': (d) =>
                _list(d, 'sessionRecords').add(_first(d, 'sessionRecords')),
            'a duplicated attempt id': (d) =>
                _list(d, 'attempts').add(_first(d, 'attempts')),
            'a duplicated assessment id': (d) =>
                _list(d, 'assessments').add(_first(d, 'assessments')),
            'a duplicated planned session id': (d) =>
                _list(d, 'plannedSessions').add(_first(d, 'plannedSessions')),
            'a membership of an unknown student': (d) =>
                ((_first(d, 'groups')['memberships']! as List<Object?>).first!
                        as Map<String, Object?>)['studentId'] =
                    'ghost',
            'a session of an unknown season': (d) =>
                _first(d, 'sessionRecords')['seasonId'] = 'ghost',
            'an attempt of an unknown student': (d) =>
                _first(d, 'attempts')['studentId'] = 'ghost',
            'an attempt of an unknown session': (d) =>
                _first(d, 'attempts')['sessionId'] = 'ghost',
            'a group of an unknown season': (d) =>
                _first(d, 'groups')['seasonId'] = 'ghost',
            'a session of an unknown group': (d) =>
                _first(d, 'sessionRecords')['groupId'] = 'ghost',
            'a present student that does not exist': (d) =>
                _first(d, 'sessionRecords')['present'] = ['ghost'],
            'an attempt on an exercise outside the catalogue': (d) =>
                _first(d, 'attempts')['blockId'] = 'ghost',
            'an attempt on an exercise number outside its block': (d) =>
                _first(d, 'attempts')['exerciseNumber'] = 999,
            'an attempt of a student absent from the session': (d) {
              _first(d, 'sessionRecords')['present'] = ['s1'];
              (_list(d, 'attempts').last!
                      as Map<String, Object?>)['sessionId'] =
                  'x1';
            },
            'a session on an unknown block': (d) =>
                _first(d, 'sessionRecords')['mainBlockId'] = 'ghost',
            'a session whose season differs from its group': (d) {
              _list(d, 'seasons').add({..._first(d, 'seasons'), 'id': 'other'});
              _first(d, 'sessionRecords')['seasonId'] = 'other';
            },
            'an assessment of an unknown student': (d) =>
                _first(d, 'assessments')['studentId'] = 'ghost',
          };
      test('a planned session on an unknown catalogue session', () async {
        final document = _parse(backup);
        (_list(document, 'plannedSessions').last!
                as Map<String, Object?>)['sheetId'] =
            'inconnue-9';

        expect(
          await _refused(target, jsonEncode(document)),
          InvariantCode.backupUnknownSheet,
        );
        await expectEmpty(target);
      });

      for (final MapEntry(key: name, value: mutate)
          in inconsistentMutations.entries) {
        test('inconsistent data: $name', () async {
          final document = _parse(backup);
          mutate(document);

          expect(
            await _refused(target, jsonEncode(document)),
            InvariantCode.backupInconsistent,
          );
          await expectEmpty(target);
        });
      }
    });
  });
}
