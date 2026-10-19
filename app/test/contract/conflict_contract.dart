import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

/// Les dépôts d'**un appareil** du club, tous ouverts sur le même serveur que
/// l'autre appareil.
typedef Device = ({
  StudentRepository students,
  GroupRepository groups,
  SeasonRepository seasons,
  SessionRepository sessions,
  SessionRecordRepository records,
  AttemptRepository attempts,
  AcquisitionRepository acquisitions,
  AcknowledgementRepository acknowledgements,
  SettingsRepository settings,
});

/// Deux appareils d'un même club sur un seul serveur.
typedef TwoDevices = ({Device a, Device b, Future<void> Function() close});

/// **La règle de conflit des données partagées** (ADR 0024, B5 ; table dans
/// l'ADR, notes FB5b, et `repositories-firestore-plan.md`) : une ligne de la
/// table, un test, nommé par son identifiant (`C1` à `C13`) ; les cas sans
/// règle sûre (`L1` à `L5`) sont des tests de **caractérisation** : ils
/// figent le comportement actuel pour que personne ne le croie corrigé.
///
/// Deux appareils écrivent « en même temps » : leurs opérations sont lancées
/// ensemble (`Future.wait`) et s'entrelacent à chaque attente. Quand le
/// résultat dépend de l'ordre d'arrivée au serveur (dernier écrit gagne), le
/// test vérifie ce qui est vrai quel que soit l'ordre : le résultat est
/// **exactement** l'une des deux écritures (jamais un mélange) et **les deux
/// appareils lisent la même chose**. Les mêmes lignes, jouées avec le vrai
/// SDK, les vraies règles et deux clients, sont dans
/// `scripts/rules_test/conflicts.test.mjs`.
///
/// [isolatedTransactions] : faux si le serveur n'isole pas les transactions
/// (le faux Firestore : deux créations simultanées s'y écrasent ; l'isolation
/// réelle est prouvée par l'émulateur) ; la création concurrente d'une saisie
/// y est alors jouée l'une après l'autre.
void conflictContract(
  String label,
  Future<TwoDevices> Function() open, {
  bool isolatedTransactions = true,
}) {
  group('$label : règle de conflit des données partagées', () {
    late TwoDevices devices;
    late Device a;
    late Device b;

    setUp(() async {
      devices = await open();
      a = devices.a;
      b = devices.b;
      // La saison, deux groupes et trois fiches, créés par l'appareil A.
      await a.seasons.save(
        Season(
          id: const SeasonId('season'),
          label: '2026-2027',
          startDate: DateTime(2026, 9),
          endDate: DateTime(2027, 6, 30),
        ),
      );
      for (final id in ['s1', 's2', 's3']) {
        await a.students.save(_student(id, 'Élève $id'));
      }
      var g1 = _group('g1');
      for (final id in ['s1', 's2']) {
        g1 = g1.admit(
          studentId: StudentId(id),
          studentAudience: Audience.children,
          from: DateTime(2026, 9),
        );
      }
      await a.groups.save(g1);
      await a.groups.save(_group('g2'));
      await a.records.save(_record('x1', 'g1', {'s1', 's2'}));
    });

    tearDown(() => devices.close());

    Future<Student> student(Device device, String id) async =>
        (await device.students.byId(StudentId(id)))!;

    // ───────────── C1 à C4 : fiches, groupes, appartenances ─────────────

    group('C1 fiche élève : dernier écrit gagne par document', () {
      test('two renames concurrently: exactly one wins, both devices agree, '
          'the groups are kept', () async {
        await Future.wait([
          a.students.save(_student('s1', 'Léa A')),
          b.students.save(_student('s1', 'Léa B')),
        ]);

        final seenByA = await student(a, 's1');
        final seenByB = await student(b, 's1');
        expect(seenByA.firstName, anyOf('Léa A', 'Léa B'));
        expect(seenByB, seenByA);
        // `groupIds` n'est jamais réécrit par un enregistrement de la fiche.
        expect(
          (await a.groups.byId(const GroupId('g1')))!.memberships,
          hasLength(2),
        );
      });
    });

    group('C2 groupes de la fiche : réunion, jamais remplacement', () {
      test('two groups admit the same student concurrently: both are kept, '
          'the student stays visible in both', () async {
        final inG1 = (await a.groups.byId(const GroupId('g1')))!;
        final inG2 = (await b.groups.byId(const GroupId('g2')))!;

        await Future.wait([
          a.groups.save(
            inG1.admit(
              studentId: const StudentId('s3'),
              studentAudience: Audience.children,
              from: DateTime(2026, 10),
            ),
          ),
          b.groups.save(
            inG2.admit(
              studentId: const StudentId('s3'),
              studentAudience: Audience.children,
              from: DateTime(2026, 10),
            ),
          ),
        ]);

        expect(await a.groups.idsEverContaining(const StudentId('s3')), {
          const GroupId('g1'),
          const GroupId('g2'),
        });
        expect(await a.students.all(), hasLength(3));
      });
    });

    group(
      'C3 groupe : dernier écrit gagne, appartenances distinctes réunies',
      () {
        test('a rename and an admission from two devices both land', () async {
          final forRename = (await a.groups.byId(const GroupId('g1')))!;
          final forAdmission = (await b.groups.byId(const GroupId('g1')))!;

          await Future.wait([
            a.groups.save(forRename.rename('Mardi')),
            b.groups.save(
              forAdmission.admit(
                studentId: const StudentId('s3'),
                studentAudience: Audience.children,
                from: DateTime(2026, 10),
              ),
            ),
          ]);

          final stored = (await a.groups.byId(const GroupId('g1')))!;
          expect(stored.name, anyOf('Mardi', 'Groupe g1'));
          expect(
            stored.memberships.map((m) => m.studentId.value).toSet(),
            containsAll(['s1', 's2']),
          );
          expect(await b.groups.byId(const GroupId('g1')), stored);
        });

        test(
          'two admissions of two different students land together',
          () async {
            final first = (await a.groups.byId(const GroupId('g2')))!;
            final second = (await b.groups.byId(const GroupId('g2')))!;

            await Future.wait([
              a.groups.save(
                first.admit(
                  studentId: const StudentId('s1'),
                  studentAudience: Audience.children,
                  from: DateTime(2026, 10),
                ),
              ),
              b.groups.save(
                second.admit(
                  studentId: const StudentId('s2'),
                  studentAudience: Audience.children,
                  from: DateTime(2026, 10),
                ),
              ),
            ]);

            final stored = (await a.groups.byId(const GroupId('g2')))!;
            expect(stored.memberships.map((m) => m.studentId.value).toSet(), {
              's1',
              's2',
            });
          },
        );
      },
    );

    group('C4 appartenance : identifiant déterministe, deux écritures '
        'identiques convergent', () {
      test('the same admission from both devices is one membership', () async {
        final first = (await a.groups.byId(const GroupId('g2')))!;
        final second = (await b.groups.byId(const GroupId('g2')))!;

        Group admit(Group group) => group.admit(
          studentId: const StudentId('s3'),
          studentAudience: Audience.children,
          from: DateTime(2026, 10),
        );
        await Future.wait([
          a.groups.save(admit(first)),
          b.groups.save(admit(second)),
        ]);

        expect(
          (await a.groups.byId(const GroupId('g2')))!.memberships,
          hasLength(1),
        );
      });
    });

    // ───────────── C5 à C7 : séances données ─────────────

    group('C5 saisie d’une séance du catalogue : une création, présents '
        'réunis', () {
      test('two devices open the same sitting: one record, all presents, '
          'the blocks of the first stay', () async {
        SessionRecord candidate(Set<String> present, String main) => _record(
          'g1_20261003_posture-1',
          'g1',
          present,
          main: main,
        ).copyWith(sheetId: SheetId('posture-1'));

        final first = a.records.open(candidate({'s1'}, 'a'));
        if (!isolatedTransactions) await first;
        await Future.wait([
          first,
          b.records.open(candidate({'s2'}, 'b')),
        ]);

        final stored = await a.records.byId(
          const SessionId('g1_20261003_posture-1'),
        );
        expect(stored!.present, {const StudentId('s1'), const StudentId('s2')});
        expect(stored.mainBlockId, anyOf('a', 'b'));
        expect(await b.records.byId(stored.id), stored);
        expect(
          (await a.records.all()).where((r) => r.id == stored.id),
          hasLength(1),
        );
      });
    });

    group('C6 saisie : enregistrer remplace en bloc, dernier écrit gagne', () {
      test('two saves: the winner is one whole write, not a mixture', () async {
        await Future.wait([
          a.records.save(_record('x1', 'g1', {'s1'}, main: 'a')),
          b.records.save(_record('x1', 'g1', {'s2'}, main: 'b')),
        ]);

        final stored = (await a.records.byId(const SessionId('x1')))!;
        final whole = [
          ({const StudentId('s1')}, 'a'),
          ({const StudentId('s2')}, 'b'),
        ];
        expect(
          whole.any(
            (w) =>
                w.$1.length == stored.present.length &&
                stored.present.containsAll(w.$1) &&
                w.$2 == stored.mainBlockId,
          ),
          isTrue,
          reason: '${stored.present} / ${stored.mainBlockId}',
        );
        expect(await b.records.byId(stored.id), stored);
      });

      test('resuming replaces the presents, opening unites them: the last '
          'to arrive decides, never a mixture of both lists', () async {
        await Future.wait([
          a.records.resume(_record('x1', 'g1', {'s1'})),
          b.records.open(_record('x1', 'g1', {'s2'})),
        ]);

        final present = (await a.records.byId(const SessionId('x1')))!.present
            .map((s) => s.value)
            .toSet();
        expect(present, anyOf(equals({'s1'}), equals({'s1', 's2'})));
      });
    });

    group('C7 étiquettes : la liste est remplacée en bloc', () {
      test('two devices tag the same sitting: one list wins whole', () async {
        await Future.wait([
          a.records.setTags(const SessionId('x1'), {SessionTag.toRedo}),
          b.records.setTags(const SessionId('x1'), {SessionTag.toRedo}),
        ]);

        expect((await a.records.byId(const SessionId('x1')))!.tags, {
          SessionTag.toRedo,
        });
      });
    });

    // ───────────── C8 à C12 : données de l'élève ─────────────

    group('C8 passages : un document par passage, ajout seul', () {
      test('two devices record passes at once: all are kept, in the same '
          'order for both', () async {
        await Future.wait([
          a.attempts.add(_attempt('a-from-a-1')),
          b.attempts.add(_attempt('a-from-b-1')),
          a.attempts.add(_attempt('a-from-a-2')),
          b.attempts.add(_attempt('a-from-b-2')),
        ]);

        final seenByA = await a.attempts.forStudent(const StudentId('s1'));
        final seenByB = await b.attempts.forStudent(const StudentId('s1'));
        expect(seenByA, hasLength(4));
        expect(seenByA.map((e) => e.id.value), seenByB.map((e) => e.id.value));
      });
    });

    group(
      'C9 correction d’un passage : dernier écrit gagne sur les billes',
      () {
        test('two corrections: one pair of balls wins whole', () async {
          await a.attempts.add(_attempt('a1'));

          await Future.wait([
            a.attempts.correct(_attempt('a1', potted: 1)),
            b.attempts.correct(_attempt('a1', potted: 4)),
          ]);

          final stored = (await a.attempts.forStudent(const StudentId('s1')))
              .single;
          expect(stored.potted, anyOf(1, 4));
          expect(stored.total, 5);
        });
      },
    );

    group('C10 blocs acquis : le calcul fusionne les doublons', () {
      test('two devices mark the same block: both documents stay, the '
          'derivation is the same whatever the order', () async {
        await Future.wait([
          a.acquisitions.add(_acquisition('qa', 5)),
          b.acquisitions.add(_acquisition('qb', 9)),
        ]);

        final stored = await a.acquisitions.forStudent(const StudentId('s1'));
        expect(stored, hasLength(2));
        final catalogue = buildCatalogue();
        StudentProgress derive(List<BlockAcquisition> list) =>
            StudentProgress.derive(
              studentId: const StudentId('s1'),
              attempts: const [],
              acquisitions: list,
              rates: catalogue.rates,
              config: RulesConfig(),
            );
        expect(
          derive(stored).acquiredBlocks.keys,
          derive(stored.reversed.toList()).acquiredBlocks.keys,
        );
        expect(
          derive(stored).acquiredOn('posture'),
          derive(stored.reversed.toList()).acquiredOn('posture'),
        );
      });
    });

    group('C11 « Vu » partagé : un document par acquittement, le calcul '
        'garde le dernier', () {
      test('two animators acknowledge the same alert: both are kept, the '
          'alert stays hidden for both devices', () async {
        await Future.wait([
          a.acknowledgements.add(_acknowledgement('ka', 5)),
          b.acknowledgements.add(_acknowledgement('kb', 6)),
        ]);

        final seenByA = await a.acknowledgements.forStudent(
          const StudentId('s1'),
        );
        final seenByB = await b.acknowledgements.forStudent(
          const StudentId('s1'),
        );
        expect(seenByA, hasLength(2));
        expect(
          seenByA.map((e) => e.id.value).toSet(),
          seenByB.map((e) => e.id.value).toSet(),
        );
      });
    });

    group('C12 séances planifiées : un document par séance', () {
      test('two devices plan different sessions: both stay, the same list '
          'for both', () async {
        await Future.wait([
          a.sessions.add(_planned('p-a', 'g1')),
          b.sessions.add(_planned('p-b', 'g1')),
        ]);

        final seenByA = await a.sessions.getAll();
        expect(seenByA.map((s) => s.id).toSet(), {'p-a', 'p-b'});
        expect(
          (await b.sessions.getAll()).map((s) => s.id),
          seenByA.map((s) => s.id),
        );
      });
    });

    // ───────────── C13 : suppression physique, réglages ─────────────

    group('C13 suppression physique et documents uniques', () {
      test(
        'two devices delete the same planned session: no error, gone',
        () async {
          await a.sessions.add(_planned('p1', 'g1'));

          await Future.wait([a.sessions.delete('p1'), b.sessions.delete('p1')]);

          expect(await a.sessions.getAll(), isEmpty);
        },
      );

      test('a correction of a passage deleted elsewhere is a not-found '
          'failure, never a silent recreation', () async {
        await a.attempts.add(_attempt('a1'));
        await b.attempts.delete(const AttemptId('a1'));

        await expectLater(
          a.attempts.correct(_attempt('a1', potted: 4)),
          throwsA(anyOf(isA<NotFound>(), isA<ServiceFailure>())),
        );
        expect(await a.attempts.forStudent(const StudentId('s1')), isEmpty);
      });

      test('the club settings: one whole write wins', () async {
        final base = await a.settings.load();
        await Future.wait([
          a.settings.save(base.copyWith(passesRequired: 3)),
          b.settings.save(base.copyWith(passesRequired: 7)),
        ]);

        final stored = await a.settings.load();
        expect(stored.passesRequired, anyOf(3, 7));
        expect(await b.settings.load(), stored);
      });
    });

    // ───────────── Limites : aucune règle sûre ─────────────

    group('limites (sans règle sûre, caractérisées)', () {
      test('L1 a stale group copy erases a membership added since', () async {
        final stale = (await b.groups.byId(const GroupId('g2')))!;
        final current = (await a.groups.byId(const GroupId('g2')))!;
        await a.groups.save(
          current.admit(
            studentId: const StudentId('s1'),
            studentAudience: Audience.children,
            from: DateTime(2026, 10),
          ),
        );

        // B n'a pas reçu l'inscription de A (copie périmée) et enregistre le
        // groupe avec une autre : l'enregistrement d'un groupe écrit son
        // agrégat entier, il supprime donc l'appartenance qu'il ne connaît pas.
        await b.groups.save(
          stale.admit(
            studentId: const StudentId('s2'),
            studentAudience: Audience.children,
            from: DateTime(2026, 10),
          ),
        );

        final stored = (await a.groups.byId(const GroupId('g2')))!;
        expect(stored.memberships.map((m) => m.studentId.value), ['s2']);
      });

      test('L2 a stale save recreates a student deleted elsewhere', () async {
        await b.students.delete(const StudentId('s3'));

        await a.students.save(_student('s3', 'Élève s3 corrigé'));

        expect(
          (await a.students.byId(const StudentId('s3')))?.firstName,
          'Élève s3 corrigé',
        );
      });

      test(
        'L3 the audience history is replaced whole by the last write',
        () async {
          final base = await student(a, 's1');
          await a.students.save(
            base.changeAudience(Audience.adults, DateTime(2026, 10)),
          );
          // B écrit une fiche lue avant le changement de A.
          await b.students.save(
            Student(
              id: base.id,
              firstName: 'Léa B',
              audienceHistory: base.audienceHistory,
            ),
          );

          final stored = await student(a, 's1');
          expect(stored.audienceHistory, base.audienceHistory);
          expect(stored.firstName, 'Léa B');
        },
      );

      test('L4 tags and presents are lists replaced whole: an addition '
          'made elsewhere in between is lost', () async {
        await a.records.setTags(const SessionId('x1'), {SessionTag.toRedo});
        await b.records.save(_record('x1', 'g1', {'s1', 's2'}));

        expect((await a.records.byId(const SessionId('x1')))!.tags, isEmpty);
      });
    });
  });
}

Student _student(String id, String name) => Student.enroll(
  id: StudentId(id),
  firstName: name,
  audience: Audience.children,
  since: DateTime(2026, 9),
);

Group _group(String id) => Group(
  id: GroupId(id),
  seasonId: const SeasonId('season'),
  name: 'Groupe $id',
  audience: Audience.children,
);

SessionRecord _record(
  String id,
  String group,
  Set<String> present, {
  String? main,
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('season'),
  date: DateTime(2026, 10, 3),
  audience: Audience.children,
  present: {for (final name in present) StudentId(name)},
  mainBlockId: main,
);

Session _planned(String id, String group) => Session(
  id: id,
  title: id,
  date: DateTime(2026, 10, 12),
  audience: Audience.children,
  groupId: GroupId(group),
);

ExerciseAttempt _attempt(String id, {int potted = 3}) => ExerciseAttempt(
  id: AttemptId(id),
  studentId: const StudentId('s1'),
  sessionId: const SessionId('x1'),
  exercise: ExerciseRef(blockId: 'puissance', number: 2),
  date: DateTime(2026, 10, 3),
  potted: potted,
  total: 5,
);

BlockAcquisition _acquisition(String id, int day) => BlockAcquisition(
  id: AcquisitionId(id),
  studentId: const StudentId('s1'),
  blockId: 'posture',
  date: DateTime(2026, 10, day),
  source: AcquisitionSource.placement,
);

AlertAcknowledgement _acknowledgement(String id, int day) =>
    AlertAcknowledgement(
      id: AcknowledgementId(id),
      studentId: const StudentId('s1'),
      exercise: ExerciseRef(blockId: 'puissance', number: 2),
      lastAttemptId: const AttemptId('a1'),
      date: DateTime(2026, 10, day),
    );
