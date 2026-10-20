import 'dart:convert';

import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/import_world.dart';
import '../../../../../support/realistic_backup.dart';

void main() {
  final backup = RealisticBackup(history: true);

  Future<ImportWorld> world(
    String content, {
    Role role = Role.director,
    bool decide = true,
  }) async {
    final w = ImportWorld.open()
      ..act(role)
      ..backup = backup
      ..content = content;
    if (decide) w.decisions = w.createAll();
    return w;
  }

  List<String> problemCodes(ImportWorld w) => [
    for (final p in w.plan!.report.problems) p.code.name,
  ];

  group('a file that cannot be used gives a blocked plan, never a failure', () {
    test('text that is not JSON', () async {
      final w = await world('pas du json');
      await w.prepare();
      expect(w.plan!.status, ImportStatus.blocked);
      expect(problemCodes(w), ['unreadable']);
    });

    test('JSON that is not a backup', () async {
      final w = await world('{"format": "autre"}');
      await w.prepare();
      expect(problemCodes(w), ['unreadable']);
    });

    test('a version the application does not read', () async {
      final document = jsonDecode(backup.content) as Map<String, Object?>;
      document['schemaVersion'] = 99;
      final w = await world(jsonEncode(document));
      await w.prepare();
      expect(problemCodes(w), ['versionUnsupported']);
    });

    test('a value that is not valid', () async {
      final document = jsonDecode(backup.content) as Map<String, Object?>;
      final students =
          (document['data']! as Map<String, Object?>)['students']!
              as List<Object?>;
      (students.first! as Map<String, Object?>)['firstName'] = '';
      final w = await world(jsonEncode(document));
      await w.prepare();
      expect(problemCodes(w), ['invalid']);
    });

    test('a date in the future that the rules of the domain refuse', () async {
      final document = jsonDecode(backup.content) as Map<String, Object?>;
      final assessments =
          (document['data']! as Map<String, Object?>)['assessments']!
              as List<Object?>;
      (assessments.first! as Map<String, Object?>)['date'] =
          '2099-01-01T00:00:00.000';
      final w = await world(jsonEncode(document));
      await w.prepare();
      expect(w.plan!.status, ImportStatus.blocked);
      expect(problemCodes(w), ['invalid']);
    });

    test('a file that is too large', () async {
      final w = await world('x' * (10 * 1024 * 1024 + 1));
      await w.prepare();
      expect(problemCodes(w), ['unreadable']);
    });
  });

  group('the integrity is reported in full', () {
    test('duplicates and dangling references are all listed', () async {
      final document = jsonDecode(backup.content) as Map<String, Object?>;
      final data = document['data']! as Map<String, Object?>;
      final attempts = data['attempts']! as List<Object?>;
      attempts
        ..add(attempts.first)
        ..add({
          ...(attempts.last! as Map<String, Object?>),
          'id': 'orphan',
          'sessionId': 'ghost',
        });
      final w = await world(jsonEncode(document));
      await w.prepare();
      expect(w.plan!.status, ImportStatus.blocked);
      expect(problemCodes(w), containsAll(['duplicateId', 'orphanAttempt']));
    });

    test('the catalogue is checked once the file is coherent', () async {
      final document = jsonDecode(backup.content) as Map<String, Object?>;
      final data = document['data']! as Map<String, Object?>;
      final planned =
          (data['plannedSessions']! as List<Object?>).first!
              as Map<String, Object?>;
      planned['sheetId'] = 'inconnue-1';
      final w = await world(jsonEncode(document));
      await w.prepare();
      expect(problemCodes(w), ['unknownSheet']);
    });

    test('an unknown block of the catalogue', () async {
      final document = jsonDecode(backup.content) as Map<String, Object?>;
      final data = document['data']! as Map<String, Object?>;
      final acquisition =
          (data['blockAcquisitions']! as List<Object?>).first!
              as Map<String, Object?>;
      acquisition['blockId'] = 'inconnu';
      final w = await world(jsonEncode(document));
      await w.prepare();
      expect(problemCodes(w), ['unknownBlock']);
    });
  });

  group('the role and the club', () {
    test('no active club is a refusal of the service', () async {
      final w = ImportWorld.open()
        ..backup = backup
        ..content = backup.content;
      final result = await w.prepareUseCase(w.content!);
      expect(
        result,
        isA<Err<ClubImportPlan>>().having(
          (e) => e.failure,
          'failure',
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
    });

    test('a teacher gets the plan of her own groups', () async {
      final single = RealisticBackup(groups: 1);
      final w = ImportWorld.open()
        ..backup = single
        ..content = single.content
        ..seedClubGroup(
          id: 'g-a',
          name: 'A',
          audience: 'children',
          teacher: 'u-import',
        )
        ..act(Role.teacher, groups: ['g-a'])
        ..decisions = ImportDecisions(
          groups: {single.groupId(1): const UseExistingGroup(GroupId('g-a'))},
        );
      await w.prepare();
      // Ses fiches sont neuves pour elle : elle confirme qu'elle ne peut pas
      // les vérifier.
      expect(w.plan!.status, ImportStatus.needsConfirmation);
      expect(w.plan!.report.unverifiableStudents, 3);
      w.decisions = w.decisions.copyWith(unverifiedConfirmed: 3);
      await w.prepare();
      expect(
        w.plan!.status,
        ImportStatus.ready,
        reason: '${w.plan!.report.problems}',
      );
    });

    test('a fiche of the file that exists outside her groups is invisible to '
        'a teacher: the plan says so, a manager sees it', () async {
      final single = RealisticBackup(groups: 1);
      ImportWorld open(Role role) {
        final w = ImportWorld.open()
          ..backup = single
          ..content = single.content
          ..seedClubGroup(
            id: 'g-a',
            name: 'A',
            audience: 'children',
            teacher: 'u-import',
          )
          ..seed('clubs/c1/students/s-g1-1', {
            'firstName': 'Déjà là',
            'audience': 'children',
            'groupIds': ['g-other'],
          })
          ..act(role, groups: role == Role.teacher ? ['g-a'] : [])
          ..decisions = ImportDecisions(
            groups: {single.groupId(1): const UseExistingGroup(GroupId('g-a'))},
          );
        return w;
      }

      final asTeacher = open(Role.teacher);
      await asTeacher.prepare();
      expect(asTeacher.plan!.report.unverifiableStudents, 3);
      expect(asTeacher.plan!.status, ImportStatus.needsConfirmation);
      final asDirector = open(Role.director);
      await asDirector.prepare();
      expect(asDirector.plan!.report.unverifiableStudents, 0);
    });

    test(
      'the fingerprint is the SHA-256 of the file, whatever the decisions',
      () async {
        final a = await world(backup.content);
        final b = await world(backup.content, decide: false);
        await a.prepare();
        await b.prepare();
        expect(a.plan!.fingerprint, sha256Hex(backup.content));
        expect(b.plan!.fingerprint, a.plan!.fingerprint);
      },
    );

    test('the date of the file and of the day give its age', () async {
      final w = await world(backup.content);
      await w.prepare();
      expect(w.plan!.report.fileAgeDays, 0);
      expect(w.plan!.version, 5);
    });

    test(
      'a finished import is recognized from the marker of the club',
      () async {
        final w = await world(backup.content);
        await w.prepare();
        await w.runPlan();
        await w.prepare();
        expect(w.plan!.status, ImportStatus.alreadyImported);
      },
    );
  });
}
