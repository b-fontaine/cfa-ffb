import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les ports de planification d'un stockage neuf : saisons, séances
/// planifiées, séances données (+ les groupes qui les portent) et sa
/// fermeture.
typedef PlanningRepos = ({
  SeasonRepository seasons,
  GroupRepository groups,
  SessionRepository sessions,
  SessionRecordRepository records,
  Future<void> Function() close,
});

Season _season(String id, int year, {String? label, DateTime? closedOn}) =>
    Season(
      id: SeasonId(id),
      label: label ?? '$year-${year + 1}',
      startDate: DateTime(year, 9),
      endDate: DateTime(year + 1, 6, 30),
      closedOn: closedOn,
    );

Group _group(String id, {String season = 'se1'}) => Group(
  id: GroupId(id),
  seasonId: SeasonId(season),
  name: 'Jeunes $id',
  audience: Audience.children,
);

Session _session(
  String id, {
  required int dayOfMonth,
  String group = 'g1',
  String? sheet,
  String title = 'Posture',
  Audience audience = Audience.children,
}) => Session(
  id: id,
  title: title,
  date: DateTime(2026, 10, dayOfMonth),
  audience: audience,
  groupId: GroupId(group),
  sheetId: sheet == null ? null : SheetId(sheet),
);

SessionRecord _record(
  String id, {
  required int dayOfMonth,
  String group = 'g1',
  Set<String> present = const {},
  String? main,
  String? recall,
  String? sheet,
  Set<SessionTag> tags = const {},
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('se1'),
  date: DateTime(2026, 10, dayOfMonth),
  audience: Audience.children,
  present: {for (final student in present) StudentId(student)},
  mainBlockId: main,
  recallBlockId: recall,
  sheetId: sheet == null ? null : SheetId(sheet),
  tags: tags,
);

/// Contrat des saisons, des séances planifiées et des séances données,
/// exécuté contre drift, la mémoire et Firestore (faux en mémoire). Les
/// listes sont attendues dans l'ordre **chronologique** : l'ordre de première
/// sauvegarde de drift et de la mémoire, que Firestore ne garde pas, y
/// coïncide (les éléments sont enregistrés du plus ancien au plus récent).
///
/// [isolatedTransactions] : le stockage isole ses transactions (drift, la
/// mémoire) ; faux pour le faux Firestore, où deux ouvertures simultanées sont
/// rejouées l'une après l'autre.
void planningContract(
  String label,
  Future<PlanningRepos> Function() open, {
  bool isolatedTransactions = true,
}) {
  group('$label : contrat de la planification', () {
    late PlanningRepos repos;

    setUp(() async {
      repos = await open();
      await repos.seasons.save(_season('se1', 2026));
      await repos.groups.save(_group('g1'));
      await repos.groups.save(_group('g2'));
    });
    tearDown(() => repos.close());

    group('saisons', () {
      test('round-trips, replaces and lists in chronological order', () async {
        await repos.seasons.save(_season('se2', 2027));
        await repos.seasons.save(_season('se1', 2026, label: 'bis'));

        expect(
          await repos.seasons.byId(const SeasonId('se1')),
          _season('se1', 2026, label: 'bis'),
        );
        expect((await repos.seasons.all()).map((s) => s.id.value), [
          'se1',
          'se2',
        ]);
        expect(await repos.seasons.byId(const SeasonId('zz')), isNull);
      });

      test('stores the closing day and reopens when saved without', () async {
        final closed = _season('se1', 2026, closedOn: DateTime(2027, 6, 30));
        await repos.seasons.save(closed);
        expect(await repos.seasons.byId(const SeasonId('se1')), closed);

        await repos.seasons.save(_season('se1', 2026));

        expect(
          (await repos.seasons.byId(const SeasonId('se1')))!.closedOn,
          isNull,
        );
      });

      test('keeps both dates of a season with a reduced end', () async {
        final reduced = Season(
          id: const SeasonId('se3'),
          label: 'Courte',
          startDate: DateTime(2026, 9, 1, 8, 30),
          endDate: DateTime.utc(2026, 12, 20, 18),
        );
        await repos.seasons.save(reduced);

        final loaded = await repos.seasons.byId(const SeasonId('se3'));
        expect(loaded, reduced);
        expect(loaded!.endDate.isUtc, isTrue);
      });

      test('deletes a season: it is no longer found', () async {
        await repos.seasons.delete(const SeasonId('se1'));

        expect(await repos.seasons.byId(const SeasonId('se1')), isNull);
        expect(await repos.seasons.all(), isEmpty);
        await repos.seasons.delete(const SeasonId('zz'));
      });
    });

    group('séances planifiées', () {
      test('round-trips a session with its group and its sheet', () async {
        final full = _session('p1', dayOfMonth: 5, sheet: 'posture-1');
        await repos.sessions.add(full);
        await repos.sessions.add(
          _session('p2', dayOfMonth: 12, group: 'g2', title: 'Autre'),
        );

        final all = await repos.sessions.getAll();
        expect(all.first, full);
        expect(all.map((s) => s.id), ['p1', 'p2']);
        expect(all.last.groupId, const GroupId('g2'));
        expect(all.last.sheetId, isNull);
      });

      test('adding a known id replaces the session', () async {
        await repos.sessions.add(_session('p1', dayOfMonth: 5));
        await repos.sessions.add(
          _session('p1', dayOfMonth: 6, title: 'Rebond', sheet: 'posture-1'),
        );

        final all = await repos.sessions.getAll();
        expect(all, hasLength(1));
        expect(all.single.title, 'Rebond');
        expect(all.single.sheetId, SheetId('posture-1'));
      });

      test('deletes a session and finds the sessions of some groups', () async {
        await repos.sessions.add(_session('p1', dayOfMonth: 5));
        await repos.sessions.add(_session('p2', dayOfMonth: 6, group: 'g2'));

        expect(await repos.sessions.idsOfGroups({const GroupId('g2')}), {'p2'});
        expect(await repos.sessions.idsOfGroups({}), isEmpty);

        await repos.sessions.delete('p1');
        await repos.sessions.delete('zz');
        expect((await repos.sessions.getAll()).map((s) => s.id), ['p2']);
      });
    });

    group('séances données', () {
      test('round-trips presences, blocks, sheet and tags', () async {
        final full = _record(
          'x1',
          dayOfMonth: 3,
          present: {'s1', 's2'},
          main: 'puissance',
          recall: 'rebond',
          sheet: 'posture-1',
          tags: {SessionTag.tooLong, SessionTag.toRedo},
        );
        final bare = _record('x2', dayOfMonth: 10);

        await repos.records.save(full);
        await repos.records.save(bare);

        expect(await repos.records.byId(const SessionId('x1')), full);
        expect(await repos.records.byId(const SessionId('x2')), bare);
        expect(await repos.records.byId(const SessionId('zz')), isNull);
      });

      test('open creates a free sitting and returns it as stored', () async {
        final candidate = _record(
          'g1_20261003_posture-1',
          dayOfMonth: 3,
          present: {'s1'},
          main: 'a',
          sheet: 'posture-1',
        );

        final opened = await repos.records.open(candidate);

        expect(opened, candidate);
        expect(await repos.records.byId(candidate.id), candidate);
      });

      test('two concurrent openings of one sitting converge', () async {
        SessionRecord candidate(Set<String> present) => _record(
          'g1_20261003_posture-1',
          dayOfMonth: 3,
          present: present,
          main: 'a',
          sheet: 'posture-1',
        );

        final first = repos.records.open(candidate({'s1'}));
        // Le faux Firestore n'isole pas ses transactions : deux créations
        // simultanées s'y écrasent. L'isolation du vrai serveur est prouvée
        // contre l'émulateur (`scripts/rules_test/planning.test.mjs`).
        if (!isolatedTransactions) await first;
        await Future.wait([
          first,
          repos.records.open(candidate({'s2', 's3'})),
        ]);

        final stored = await repos.records.all();
        expect(stored, hasLength(1));
        expect(stored.single.present, {
          const StudentId('s1'),
          const StudentId('s2'),
          const StudentId('s3'),
        });
        expect(stored.single.mainBlockId, 'a');
      });

      test('open keeps the blocks and the tags, adds the presents', () async {
        await repos.records.save(
          _record(
            'x1',
            dayOfMonth: 3,
            present: {'s1'},
            main: 'a',
            tags: {SessionTag.toRedo},
          ),
        );

        final opened = await repos.records.open(
          _record('x1', dayOfMonth: 3, present: {'s2'}, main: 'b'),
        );

        expect(opened.mainBlockId, 'a');
        expect(opened.tags, {SessionTag.toRedo});
        expect(opened.present, {const StudentId('s1'), const StudentId('s2')});
        expect(await repos.records.byId(const SessionId('x1')), opened);
      });

      test('resume changes the blocks and replaces the presents', () async {
        await repos.records.save(
          _record(
            'x1',
            dayOfMonth: 3,
            present: {'s1', 's2'},
            main: 'a',
            tags: {SessionTag.toRedo},
          ),
        );

        final resumed = await repos.records.resume(
          _record('x1', dayOfMonth: 3, present: {'s3'}, main: 'b', recall: 'c'),
        );

        expect(resumed.mainBlockId, 'b');
        expect(resumed.recallBlockId, 'c');
        expect(resumed.tags, {SessionTag.toRedo});
        // Décocher un élève coché par erreur doit rester possible.
        expect(resumed.present, {const StudentId('s3')});
        expect(await repos.records.byId(const SessionId('x1')), resumed);
      });

      test('replaces the presences and the blocks when saved again', () async {
        await repos.records.save(
          _record('x1', dayOfMonth: 3, present: {'s1', 's2'}, main: 'a'),
        );
        await repos.records.save(_record('x1', dayOfMonth: 3, present: {'s2'}));

        final read = await repos.records.byId(const SessionId('x1'));
        expect(read!.present, {const StudentId('s2')});
        expect(read.mainBlockId, isNull);
        expect(await repos.records.all(), hasLength(1));
      });

      test('lists a group and a student from oldest to newest', () async {
        await repos.records.save(_record('x1', dayOfMonth: 3, present: {'s1'}));
        await repos.records.save(
          _record('x2', dayOfMonth: 4, group: 'g2', present: {'s1', 's2'}),
        );
        await repos.records.save(
          _record('x3', dayOfMonth: 10, present: {'s2'}),
        );

        expect(
          (await repos.records.forGroup(const GroupId('g1')))
              .map((r) => r.id.value),
          ['x1', 'x3'],
        );
        expect(
          (await repos.records.forStudent(const StudentId('s1')))
              .map((r) => r.id.value),
          ['x1', 'x2'],
        );
        expect(await repos.records.forStudent(const StudentId('zz')), isEmpty);
        expect(await repos.records.all(), hasLength(3));
      });

      test(
        'replaces the tags and nothing else, ignoring unknown ids',
        () async {
          final record = _record(
            'x1',
            dayOfMonth: 3,
            present: {'s1'},
            main: 'a',
            tags: {SessionTag.tooEasy},
          );
          await repos.records.save(record);

          await repos.records.setTags(const SessionId('x1'), {
            SessionTag.gameAppreciated,
          });
          await repos.records.setTags(const SessionId('zz'), {
            SessionTag.toRedo,
          });

          expect(
            await repos.records.byId(const SessionId('x1')),
            record.copyWith(tags: {SessionTag.gameAppreciated}),
          );
          expect(await repos.records.byId(const SessionId('zz')), isNull);
        },
      );

      test('deletes a record: it disappears everywhere', () async {
        await repos.records.save(_record('x1', dayOfMonth: 3, present: {'s1'}));
        await repos.records.delete(const SessionId('x1'));
        await repos.records.delete(const SessionId('zz'));

        expect(await repos.records.byId(const SessionId('x1')), isNull);
        expect(await repos.records.all(), isEmpty);
        expect(await repos.records.forGroup(const GroupId('g1')), isEmpty);
        expect(await repos.records.forStudent(const StudentId('s1')), isEmpty);
      });

      test('erases the presence of a student, the sessions stay', () async {
        await repos.records.save(
          _record('x1', dayOfMonth: 3, present: {'s1', 's2'}),
        );
        await repos.records.save(
          _record('x2', dayOfMonth: 4, group: 'g2', present: {'s1'}),
        );

        expect(await repos.records.idsEverPresent(const StudentId('s1')), {
          const SessionId('x1'),
          const SessionId('x2'),
        });

        await repos.records.eraseStudent(const StudentId('s1'));

        expect(
          await repos.records.idsEverPresent(const StudentId('s1')),
          isEmpty,
        );
        expect((await repos.records.byId(const SessionId('x1')))!.present, {
          const StudentId('s2'),
        });
        expect(
          (await repos.records.byId(const SessionId('x2')))!.present,
          isEmpty,
        );
        expect(await repos.records.all(), hasLength(2));
      });
    });
  });
}
