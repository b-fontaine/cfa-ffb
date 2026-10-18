import 'dart:convert';
import 'dart:io';

import 'package:billard_cfa/entities/exercise_catalog/data/catalogue_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
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
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/backup_formats.dart';
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
  r.seasonArchives,
  r.students,
  r.groups,
  r.sessionRecords,
  r.attempts,
  r.acquisitions,
  r.acknowledgements,
  r.assessments,
  r.sessions,
  BackupCodec(),
  _FixedClock(),
  r.rules,
);

ImportBackup _import(RepositoryHarness r) => ImportBackup(
  r.seasons,
  r.seasonArchives,
  r.students,
  r.groups,
  r.sessionRecords,
  r.attempts,
  r.acquisitions,
  r.acknowledgements,
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
  r.settings,
  r.rules,
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
/// groupe, deux séances, trois passages, un bloc acquis, un bilan et une
/// séance planifiée.
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
        tags: id == 'x2'
            ? {SessionTag.gameAppreciated, SessionTag.tooLong}
            : const {},
      ),
    );
  }
  for (final (id, student, session) in [
    ('a1', 's1', 'x1'),
    ('a2', 's1', 'x1'),
    ('a3', 's2', 'x2'),
  ]) {
    await r.attempts.add(
      ExerciseAttempt(
        id: AttemptId(id),
        studentId: StudentId(student),
        sessionId: SessionId(session),
        exercise: ExerciseRef(blockId: 'puissance', number: 1),
        date: DateTime(2026, 10, 3),
        potted: 4,
        total: 5,
      ),
    );
  }
  await r.acquisitions.add(
    BlockAcquisition(
      id: const AcquisitionId('q1'),
      studentId: const StudentId('s2'),
      blockId: 'puissance',
      date: DateTime(2026, 9, 15),
      source: AcquisitionSource.placement,
    ),
  );
  await r.acknowledgements.add(
    AlertAcknowledgement(
      id: const AcknowledgementId('k1'),
      studentId: const StudentId('s1'),
      exercise: ExerciseRef(blockId: 'puissance', number: 1),
      lastAttemptId: const AttemptId('a2'),
      date: DateTime(2026, 10, 5),
    ),
  );
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

SeasonArchive _archive(String season, {int sessions = 2}) => SeasonArchive(
  seasonId: SeasonId(season),
  audiences: [
    AudienceArchive(
      audience: Audience.children,
      sessionCount: sessions,
      presenceCount: 4,
      possiblePresenceCount: 4,
      studentCount: 3,
      attemptCount: 3,
    ),
  ],
  exercises: [
    ExerciseArchive(
      audience: Audience.children,
      exercise: ExerciseRef(blockId: 'puissance', number: 1),
      studentCount: 3,
      attemptCount: 3,
      potted: 12,
      total: 15,
    ),
  ],
);

/// Clôt la saison `season` du club de test au 12 octobre 2026, avec son
/// archive, et efface l'élève `s1` comme le fait une clôture.
Future<void> _closeSeason(RepositoryHarness r) async {
  final season = (await r.seasons.byId(const SeasonId('season')))!;
  await r.seasons.save(season.copyWith(closedOn: DateTime(2026, 10, 12)));
  await r.seasonArchives.save(_archive('season'));
  const lea = StudentId('s1');
  await r.attempts.eraseStudent(lea);
  await r.acknowledgements.eraseStudent(lea);
  await r.assessments.eraseStudent(lea);
  await r.sessionRecords.eraseStudent(lea);
  await r.groups.eraseStudent(lea);
  await r.students.erase(lea);
}

Map<String, Object?> _parse(String content) =>
    jsonDecode(content) as Map<String, Object?>;

List<Object?> _list(Map<String, Object?> document, String key) =>
    (document['data']! as Map<String, Object?>)[key]! as List<Object?>;

Map<String, Object?> _first(Map<String, Object?> document, String key) =>
    _list(document, key).first! as Map<String, Object?>;

/// Avec le stockage Firestore, l'import d'une sauvegarde n'est PAS supporté
/// avant FB7 (une saisie se crée par une transaction, impossible dans le lot
/// atomique d'une unité de travail) : il échoue par un `ServiceFailure`
/// explicite (jamais une exception hors `Failure`) et **n'écrit rien**, ni
/// côté Firestore ni côté drift.
void backupImportUnsupportedContract(
  String label,
  Future<RepositoryHarness> Function() openSource,
  Future<RepositoryHarness> Function() openTarget,
) {
  group('$label : import de sauvegarde non supporté (avant FB7)', () {
    late RepositoryHarness source;
    late RepositoryHarness target;

    setUp(() async {
      source = await openSource();
      target = await openTarget();
      await _seed(source);
    });
    tearDown(() async {
      await source.close();
      await target.close();
    });

    test(
      'is refused with an explicit service failure and writes nothing',
      () async {
        final result = await _import(target)(await _exported(source));

        switch (result) {
          case Ok(:final value):
            fail('import accepté : $value');
          case Err(:final failure):
            expect(failure, isA<ServiceFailure>());
            expect(
              (failure as ServiceFailure).code,
              ServiceFailureCode.unsupported,
            );
        }
        expect(await target.students.all(), isEmpty);
        expect(await target.seasons.all(), isEmpty);
        expect(await target.groups.all(), isEmpty);
        expect(await target.sessionRecords.all(), isEmpty);
        expect(await target.attempts.all(), isEmpty);
        expect(await target.sessions.getAll(), isEmpty);
      },
    );
  });
}

/// Avec le stockage Firestore, l'import d'une sauvegarde **sans aucune saisie**
/// (donc sans passage ni acquittement, qui en dépendent) est supporté : fiches,
/// saisons, groupes, séances planifiées, blocs acquis et bilans partent dans le
/// lot de l'unité de travail, atomiquement. C'est la seule frontière de
/// l'import avant FB7 : la moindre saisie le rend `unsupported` (voir
/// `backupImportUnsupportedContract`). Comportement figé ici pour qu'un
/// changement de la création des saisies (transaction `createIfAbsent`) ne le
/// déplace pas sans qu'on le voie.
void backupImportWithoutSittingContract(
  String label,
  Future<RepositoryHarness> Function() openSource,
  Future<RepositoryHarness> Function() openTarget,
) {
  group("$label : import d'une sauvegarde sans saisie", () {
    late RepositoryHarness source;
    late RepositoryHarness target;
    late String withoutSittings;
    late String withoutSittingsAndGroupless;

    setUp(() async {
      source = await openSource();
      target = await openTarget();
      await _seed(source);
      final document = _parse(await _exported(source));
      final data = document['data']! as Map<String, Object?>;
      for (final key in [
        'sessionRecords',
        'attempts',
        'alertAcknowledgements',
      ]) {
        data[key] = <Object?>[];
      }
      withoutSittings = jsonEncode(document);
      // La séance planifiée sans groupe (d'avant la règle) : écartée ici, son
      // cas est celui du second test.
      final planned = (data['plannedSessions']! as List<Object?>)
          .cast<Map<String, Object?>>();
      data['plannedSessions'] = [
        for (final session in planned)
          if (session['groupId'] != null) session,
      ];
      withoutSittingsAndGroupless = jsonEncode(document);
    });
    tearDown(() async {
      await source.close();
      await target.close();
    });

    test(
      'is accepted and writes everything that does not need a sitting',
      () async {
        final result = await _import(target)(withoutSittingsAndGroupless);

        switch (result) {
          case Err(:final failure):
            fail('import refusé : $failure');
          case Ok(:final value):
            expect(value.sessionRecords, 0);
            expect(value.attempts, 0);
            expect(value.students, 2);
            expect(value.groups, 1);
            expect(value.seasons, 1);
            expect(value.plannedSessions, 1);
            expect(value.blockAcquisitions, 1);
        }
        expect(await target.students.all(), hasLength(2));
        expect(await target.seasons.all(), hasLength(1));
        expect(await target.groups.all(), hasLength(1));
        expect(await target.sessions.getAll(), isNotEmpty);
        expect(await target.acquisitions.all(), hasLength(1));
        expect(await target.assessments.all(), hasLength(1));
        expect(await target.sessionRecords.all(), isEmpty);
        expect(await target.attempts.all(), isEmpty);
      },
    );

    test('is refused, writing nothing, when a planned session has no group '
        '(those of drift before the rule are taken over at FB7)', () async {
      final result = await _import(target)(withoutSittings);

      switch (result) {
        case Ok(:final value):
          fail('import accepté : $value');
        case Err(:final failure):
          expect(failure, isA<ServiceFailure>());
      }
      expect(await target.students.all(), isEmpty);
      expect(await target.seasons.all(), isEmpty);
      expect(await target.groups.all(), isEmpty);
      expect(await target.sessions.getAll(), isEmpty);
      expect(await target.acquisitions.all(), isEmpty);
    });
  });
}

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
      expect(await r.acquisitions.all(), isEmpty);
      expect(await r.acknowledgements.all(), isEmpty);
      expect(await r.assessments.all(), isEmpty);
      expect(await r.sessions.getAll(), isEmpty);
    }

    group('running guided sessions (ADR 0020)', () {
      RunProgress running() => RunProgress(
        key: RunProgressKey(sheetId: SheetId('posture-9')),
        updatedAt: DateTime.utc(2026, 10, 12, 8),
        step: 4,
        counts: const {'ini': 2},
        scoreA: 3,
      );

      test('do not move the backup format: 5 is the tags of the sessions, '
          'not them (ADR 0023)', () {
        expect(BackupCodec.currentVersion, 5);
      });

      test('are not exported: the file knows nothing of them', () async {
        await source.runProgress.save(running());

        final exported = await _exported(source);

        expect(exported, backup);
        expect(exported, isNot(contains('posture-9')));
        expect(_parse(exported).keys, isNot(contains('runProgress')));
      });

      test('are left alone by an import', () async {
        await target.runProgress.save(running());

        await _imported(target, backup);

        expect(await target.runProgress.all(), [running()]);
      });
    });

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
          blockAcquisitions: 1,
          alertAcknowledgements: 1,
          settings: true,
        ),
      );
    });

    group('settings (format 2)', () {
      const settingsKey = 'settings';

      Map<String, Object?> settingsOf(String content) =>
          (_parse(content)['data']! as Map<String, Object?>)[settingsKey]!
              as Map<String, Object?>;

      test('exports the current settings', () async {
        source.rules.current = RulesConfig(
          passesRequired: 3,
          backupReminderDays: 14,
        );

        final settings = settingsOf(await _exported(source));

        expect(settings, {
          'passesRequired': 3,
          'alertThreshold': 3,
          'recallStaleSessions': 4,
          'groupFailureSharePercent': 50,
          'backupReminderDays': 14,
        });
      });

      test('restores the settings and the current rules', () async {
        source.rules.current = RulesConfig(alertThreshold: 4);
        final content = await _exported(source);

        await _imported(target, content);

        expect((await target.settings.load()).alertThreshold, 4);
        expect(target.rules.current.alertThreshold, 4);
      });

      test('keeps the settings in place when the file has none', () async {
        await target.settings.save(
          ClubSettings.defaults.copyWith(passesRequired: 4),
        );
        target.rules.current = RulesConfig(passesRequired: 4);
        final document = _parse(backup)..['schemaVersion'] = 1;
        (document['data']! as Map<String, Object?>)
          ..remove(settingsKey)
          ..remove('seasonArchives')
          ..remove('alertAcknowledgements');
        dropSessionTags(document['data']! as Map<String, Object?>);

        await _imported(target, jsonEncode(document));

        expect(await target.students.all(), hasLength(2));
        expect((await target.settings.load()).passesRequired, 4);
        expect(target.rules.current.passesRequired, 4);
      });

      test('refuses a settings key in a file of format 1', () async {
        final document = _parse(backup)..['schemaVersion'] = 1;
        (document['data']! as Map<String, Object?>)
          ..remove('alertAcknowledgements')
          ..remove('seasonArchives');
        dropSessionTags(document['data']! as Map<String, Object?>);

        expect(
          await _refused(target, jsonEncode(document)),
          InvariantCode.backupInvalid,
        );
        await expectEmpty(target);
      });

      final invalidSettings = <String, void Function(Map<String, Object?>)>{
        'a setting above its bound': (s) => s['alertThreshold'] = 6,
        'a setting below its bound': (s) => s['passesRequired'] = 0,
        'a reminder delay above one year': (s) => s['backupReminderDays'] = 366,
        'a setting that is not an integer': (s) => s['passesRequired'] = '5',
        'a missing setting': (s) => s.remove('recallStaleSessions'),
      };
      for (final entry in invalidSettings.entries) {
        test('refuses ${entry.key} without writing anything', () async {
          final document = _parse(backup);
          final data = document['data']! as Map<String, Object?>;
          entry.value(data[settingsKey]! as Map<String, Object?>);

          expect(
            await _refused(target, jsonEncode(document)),
            InvariantCode.backupInvalid,
          );
          await expectEmpty(target);
          expect(await target.settings.load(), ClubSettings.defaults);
          expect(target.rules.current, RulesConfig());
        });
      }

      test('refuses settings that are not an object', () async {
        final document = _parse(backup);
        (document['data']! as Map<String, Object?>)[settingsKey] = [1, 2];

        expect(
          await _refused(target, jsonEncode(document)),
          InvariantCode.backupInvalid,
        );
        await expectEmpty(target);
      });
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

    test('keeps the acquired blocks of a student', () async {
      await _imported(target, backup);

      final acquired = await target.acquisitions.forStudent(
        const StudentId('s2'),
      );
      expect(acquired.single.blockId, 'puissance');
      expect(acquired.single.date, DateTime(2026, 9, 15));
      expect(
        _first(_parse(backup), 'blockAcquisitions')['source'],
        'placement',
      );
    });

    test('keeps the alert acknowledgements of a student', () async {
      await _imported(target, backup);

      final seen = await target.acknowledgements.forStudent(
        const StudentId('s1'),
      );
      expect(
        seen.single.exercise,
        ExerciseRef(blockId: 'puissance', number: 1),
      );
      expect(seen.single.lastAttemptId, const AttemptId('a2'));
      expect(seen.single.date, DateTime(2026, 10, 5));
      expect(
        _first(_parse(backup), 'alertAcknowledgements')['blockId'],
        'puissance',
      );
    });

    test('exports nothing of a restored alert', () async {
      await source.acknowledgements.delete(const AcknowledgementId('k1'));

      expect(
        _list(_parse(await _exported(source)), 'alertAcknowledgements'),
        isEmpty,
      );
    });

    group('acknowledgements across formats', () {
      Map<String, Object?> asFormat(int version) {
        final document = _parse(backup)..['schemaVersion'] = version;
        (document['data']! as Map<String, Object?>)
          ..remove('alertAcknowledgements')
          ..remove('seasonArchives');
        dropSessionTags(document['data']! as Map<String, Object?>);
        return document;
      }

      for (final version in [1, 2]) {
        test('importing a file of format $version erases those in place '
            'and keeps the data', () async {
          await target.acknowledgements.add(
            AlertAcknowledgement(
              id: const AcknowledgementId('kz'),
              studentId: const StudentId('other'),
              exercise: ExerciseRef(blockId: 'posture', number: 1),
              lastAttemptId: const AttemptId('z1'),
              date: DateTime(2026, 10, 6),
            ),
          );
          final document = asFormat(version);
          (document['data']! as Map<String, Object?>).remove('settings');

          await _imported(target, jsonEncode(document));

          expect(await target.acknowledgements.all(), isEmpty);
          expect(await target.students.all(), hasLength(2));
          expect(await target.attempts.all(), hasLength(3));
        });
      }

      test(
        'a file of format 3 keeps the others in place and adds its own',
        () async {
          await target.acknowledgements.add(
            AlertAcknowledgement(
              id: const AcknowledgementId('kz'),
              studentId: const StudentId('other'),
              exercise: ExerciseRef(blockId: 'posture', number: 1),
              lastAttemptId: const AttemptId('z1'),
              date: DateTime(2026, 10, 6),
            ),
          );

          await _imported(target, backup);

          expect(
            (await target.acknowledgements.all()).map((a) => a.id.value),
            unorderedEquals(['kz', 'k1']),
          );
        },
      );

      test('a file of format 3 with an empty list leaves those in place, '
          'unlike the missing list of an old format', () async {
        await target.acknowledgements.add(
          AlertAcknowledgement(
            id: const AcknowledgementId('kz'),
            studentId: const StudentId('other'),
            exercise: ExerciseRef(blockId: 'posture', number: 1),
            lastAttemptId: const AttemptId('z1'),
            date: DateTime(2026, 10, 6),
          ),
        );
        final document = _parse(backup);
        (document['data']! as Map<String, Object?>)['alertAcknowledgements'] =
            <Object?>[];

        await _imported(target, jsonEncode(document));

        expect((await target.acknowledgements.all()).map((a) => a.id.value), [
          'kz',
        ]);
        expect(await target.students.all(), hasLength(2));
      });

      test('a refused file of an old format erases nothing', () async {
        await target.acknowledgements.add(
          AlertAcknowledgement(
            id: const AcknowledgementId('kz'),
            studentId: const StudentId('other'),
            exercise: ExerciseRef(blockId: 'posture', number: 1),
            lastAttemptId: const AttemptId('z1'),
            date: DateTime(2026, 10, 6),
          ),
        );
        final document = asFormat(2);
        _first(document, 'attempts')['potted'] = 9;
        (document['data']! as Map<String, Object?>).remove('settings');

        expect(
          await _refused(target, jsonEncode(document)),
          InvariantCode.backupInvalid,
        );

        expect(await target.acknowledgements.all(), hasLength(1));
      });
    });

    test('exports nothing of a revoked acquired block', () async {
      await source.acquisitions.delete(const AcquisitionId('q1'));

      expect(
        _list(_parse(await _exported(source)), 'blockAcquisitions'),
        isEmpty,
      );
    });

    test('is idempotent: importing twice changes nothing', () async {
      await _imported(target, backup);
      await _imported(target, backup);

      expect(await _exported(target), backup);
      expect(await target.attempts.all(), hasLength(3));
    });

    test('writes the derived rank of each pass and reads the file in its '
        'recording order, whatever the ranks it carries', () async {
      final document = _parse(backup);
      final attempts = _list(document, 'attempts').cast<Map<String, Object?>>();
      // Rang dérivé de l'ordre d'enregistrement (ADR 0024, décision 17).
      expect(
        [for (final a in attempts) (a['id'], a['passIndex'])],
        [('a1', 1), ('a2', 2), ('a3', 1)],
      );

      // Un fichier des formats 1 à 5 porte un rang stocké que la lecture
      // ignore : l'ordre du fichier est l'ordre d'enregistrement.
      for (final attempt in attempts) {
        attempt['passIndex'] = 99;
      }
      await _imported(target, jsonEncode(document));

      expect(
        [for (final a in await target.attempts.all()) a.id.value],
        ['a1', 'a2', 'a3'],
      );
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

    group('clôture de saison (format 4)', () {
      test('round-trips the closing day and the archive', () async {
        final season = (await source.seasons.byId(const SeasonId('season')))!;
        await source.seasons.save(
          season.copyWith(closedOn: DateTime(2026, 10, 12)),
        );
        await source.seasonArchives.save(_archive('season'));
        final closed = await _exported(source);

        final summary = await _imported(target, closed);

        expect(summary.seasonArchives, 1);
        expect(
          (await target.seasons.byId(const SeasonId('season')))!.closedOn,
          DateTime(2026, 10, 12),
        );
        expect(
          await target.seasonArchives.bySeason(const SeasonId('season')),
          _archive('season'),
        );
        expect(await _exported(target), closed);
      });

      test('the archive of the file replaces the one in place', () async {
        final season = (await source.seasons.byId(const SeasonId('season')))!;
        await source.seasons.save(
          season.copyWith(closedOn: DateTime(2026, 10, 12)),
        );
        await source.seasonArchives.save(_archive('season'));
        await target.seasonArchives.save(_archive('season', sessions: 9));

        await _imported(target, await _exported(source));

        final stored = await target.seasonArchives.bySeason(
          const SeasonId('season'),
        );
        expect(stored!.audienceOf(Audience.children)!.sessionCount, 2);
      });

      test('refuses a file from before the closure of a season in place, '
          'so the erased students stay erased', () async {
        await _imported(target, backup);
        await _closeSeason(target);
        final archive = await target.seasonArchives.bySeason(
          const SeasonId('season'),
        );

        expect(
          await _refused(target, backup),
          InvariantCode.backupReopensClosedSeason,
        );

        expect(await target.students.byId(const StudentId('s1')), isNull);
        expect(
          (await target.seasons.byId(const SeasonId('season')))!.isClosed,
          isTrue,
        );
        expect(
          await target.seasonArchives.bySeason(const SeasonId('season')),
          archive,
        );
      });

      test('still accepts a file that gives the closed season closed '
          'too', () async {
        await _imported(target, backup);
        await _closeSeason(target);
        final closed = await _exported(target);

        await _imported(target, closed);

        expect(
          (await target.seasons.byId(const SeasonId('season')))!.isClosed,
          isTrue,
        );
      });

      test('an older format file leaves the archives of the other seasons '
          'alone', () async {
        await target.seasons.save(
          Season(
            id: const SeasonId('past'),
            label: '2025-2026',
            startDate: DateTime(2025, 9),
            endDate: DateTime(2026, 6, 30),
            closedOn: DateTime(2026, 6, 30),
          ),
        );
        await target.seasonArchives.save(_archive('past'));
        final document = _parse(backup)..['schemaVersion'] = 3;
        (document['data']! as Map<String, Object?>).remove('seasonArchives');
        dropSessionTags(document['data']! as Map<String, Object?>);

        await _imported(target, jsonEncode(document));

        expect(
          await target.seasonArchives.bySeason(const SeasonId('past')),
          _archive('past'),
        );
        expect(
          (await target.seasons.byId(const SeasonId('past')))!.isClosed,
          isTrue,
        );
      });

      test('refuses an archive of a season the file does not close, '
          'writing nothing', () async {
        final document = _parse(backup);
        (document['data']! as Map<String, Object?>)['seasonArchives'] = [
          {
            'seasonId': 'season',
            'audiences': <Object?>[],
            'exercises': <Object?>[],
          },
        ];

        expect(
          await _refused(target, jsonEncode(document)),
          InvariantCode.backupInconsistent,
        );
        await expectEmpty(target);
      });
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

      for (final version in <Object?>[0, 6, 99, '1', null]) {
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
        'a missing alertAcknowledgements section': (d) =>
            (d['data']! as Map<String, Object?>).remove(
              'alertAcknowledgements',
            ),
        'an acknowledgement dated at an hour of the day': (d) =>
            _first(d, 'alertAcknowledgements')['date'] =
                '2026-10-05T10:00:00.000',
        'an acknowledgement with an invalid exercise number': (d) =>
            _first(d, 'alertAcknowledgements')['exerciseNumber'] = 0,
        'an acknowledgement dated in the future': (d) =>
            _first(d, 'alertAcknowledgements')['date'] =
                '2027-05-01T00:00:00.000',
        'a missing blockAcquisitions section': (d) =>
            (d['data']! as Map<String, Object?>).remove('blockAcquisitions'),
        'an acquired block with an unknown source': (d) =>
            _first(d, 'blockAcquisitions')['source'] = 'magie',
        'an acquired block dated in the future': (d) =>
            _first(d, 'blockAcquisitions')['date'] = '2027-05-01T00:00:00.000',
        'an acquired block dated at an hour of the day': (d) =>
            _first(d, 'blockAcquisitions')['date'] = '2026-09-15T10:00:00.000',
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
            'a duplicated acquired block id': (d) => _list(
              d,
              'blockAcquisitions',
            ).add(_first(d, 'blockAcquisitions')),
            'the same block acquired twice for a student': (d) => _list(
              d,
              'blockAcquisitions',
            ).add({..._first(d, 'blockAcquisitions'), 'id': 'q2'}),
            'an acquired block of an unknown student': (d) =>
                _first(d, 'blockAcquisitions')['studentId'] = 'ghost',
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

      test('an acquired block unknown to the catalogue', () async {
        final document = _parse(backup);
        _first(document, 'blockAcquisitions')['blockId'] = 'ghost';

        expect(
          await _refused(target, jsonEncode(document)),
          InvariantCode.backupUnknownBlock,
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
