import 'dart:convert';

import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/backup_formats.dart';
import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

final _exportedAt = DateTime.utc(2026, 10, 12, 8);

final _closedSeason = Season(
  id: const SeasonId('season'),
  label: '2026-2027',
  startDate: day(1),
  endDate: day(12),
  closedOn: day(12),
);

final _archive = SeasonArchive(
  seasonId: const SeasonId('season'),
  audiences: [
    AudienceArchive(
      audience: Audience.children,
      sessionCount: 3,
      presenceCount: 7,
      possiblePresenceCount: 9,
      studentCount: 4,
      attemptCount: 11,
    ),
  ],
  exercises: [
    ExerciseArchive(
      audience: Audience.children,
      exercise: ref('a', 1),
      studentCount: 3,
      attemptCount: 6,
      potted: 12,
      total: 30,
    ),
  ],
);

final _snapshot = BackupSnapshot(
  seasons: [_closedSeason],
  blockAcquisitions: const [],
  alertAcknowledgements: const [],
  seasonArchives: [_archive],
);

InvariantCode _codeOf(String content) {
  try {
    BackupCodec().decode(content);
  } on InvariantViolation catch (violation) {
    return violation.code;
  }
  fail('le fichier aurait dû être refusé');
}

void main() {
  final codec = BackupCodec();

  Map<String, Object?> document() =>
      jsonDecode(codec.encode(_snapshot, exportedAt: _exportedAt))
          as Map<String, Object?>;
  Map<String, Object?> data(Map<String, Object?> d) =>
      d['data']! as Map<String, Object?>;
  Map<String, Object?> firstArchive(Map<String, Object?> d) =>
      (data(d)['seasonArchives']! as List<Object?>).first!
          as Map<String, Object?>;
  Map<String, Object?> firstOf(Map<String, Object?> archive, String key) =>
      (archive[key]! as List<Object?>).first! as Map<String, Object?>;

  group('format 4', () {
    test('is still read, and so are the older ones (the current is 5)', () {
      expect(BackupCodec.currentVersion, 5);
      expect(BackupCodec.supportedVersions, {1, 2, 3, 4, 5});
      expect(document()['schemaVersion'], 5);
    });

    test('writes the closing day of a closed season only', () {
      final seasons = data(document())['seasons']! as List<Object?>;

      expect((seasons.single! as Map<String, Object?>)['closedOn'], isNotNull);
      final open = jsonDecode(
        codec.encode(
          const BackupSnapshot(blockAcquisitions: [], seasonArchives: []),
          exportedAt: _exportedAt,
        ),
      ) as Map<String, Object?>;
      expect(data(open)['seasonArchives'], <Object?>[]);
    });

    test('round-trips the closure and the archive', () {
      final read = codec.decode(
        codec.encode(_snapshot, exportedAt: _exportedAt),
      );

      expect(read.seasons.single, _closedSeason);
      expect(read.seasons.single.closedOn, day(12));
      expect(read.seasonArchives, [_archive]);
    });

    test('an open season is written without closing day and read open', () {
      final snapshot = _snapshot.copyWith(
        seasons: [_closedSeason.copyWith(closedOn: null)],
        seasonArchives: const [],
      );
      final content = codec.encode(snapshot, exportedAt: _exportedAt);

      final season =
          (data(jsonDecode(content) as Map<String, Object?>)['seasons']!
                      as List<Object?>)
                  .single!
              as Map<String, Object?>;
      expect(season.containsKey('closedOn'), isFalse);
      expect(codec.decode(content).seasons.single.isClosed, isFalse);
    });

    test('writes the archive without any student, group or session date', () {
      final text = jsonEncode(firstArchive(document()));

      expect(text, isNot(contains('studentId')));
      expect(text, isNot(contains('groupId')));
      expect(text, isNot(contains('date')));
    });

    test('the archive key is mandatory', () {
      final d = document();
      data(d).remove('seasonArchives');

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });
  });

  group('formats 1 to 3', () {
    test('read as having no archive, whatever the closing day', () {
      for (final version in [1, 2, 3]) {
        final d = document()..['schemaVersion'] = version;
        data(d).remove('seasonArchives');
        dropSessionTags(data(d));
        if (version < 3) data(d).remove('alertAcknowledgements');
        if (version < 2) data(d).remove('settings');

        final read = codec.decode(jsonEncode(d));

        expect(read.seasonArchives, isEmpty, reason: 'format $version');
        expect(read.seasons.single.closedOn, day(12));
      }
    });

    test('refuse the archive key', () {
      for (final version in [1, 2, 3]) {
        final d = document()..['schemaVersion'] = version;
        dropSessionTags(data(d));
        if (version < 3) data(d).remove('alertAcknowledgements');
        if (version < 2) data(d).remove('settings');

        expect(
          _codeOf(jsonEncode(d)),
          InvariantCode.backupInvalid,
          reason: 'format $version ne connaît pas la clé',
        );
      }
    });
  });

  group('refuses', () {
    test('a closing day carrying a time', () {
      final d = document();
      ((data(d)['seasons']! as List<Object?>).single!
              as Map<String, Object?>)['closedOn'] =
          '2026-10-12T10:30:00.000';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a closing day before the start of the season', () {
      final d = document();
      ((data(d)['seasons']! as List<Object?>).single!
              as Map<String, Object?>)['closedOn'] =
          '2026-09-30T00:00:00.000';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an archive of a season that is not in the file', () {
      final d = document();
      firstArchive(d)['seasonId'] = 'ghost';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('an archive of a season that is not closed', () {
      final d = document();
      ((data(d)['seasons']! as List<Object?>).single! as Map<String, Object?>)
          .remove('closedOn');

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('two archives for the same season', () {
      final d = document();
      (data(d)['seasonArchives']! as List<Object?>).add(firstArchive(d));

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('two audience blocks for the same audience', () {
      final d = document();
      (firstArchive(d)['audiences']! as List<Object?>).add(
        firstOf(firstArchive(d), 'audiences'),
      );

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('an exercise line below the threshold of distinct students', () {
      final d = document();
      firstOf(firstArchive(d), 'exercises')['studentCount'] = 2;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('more presences than possible presences', () {
      final d = document();
      firstOf(firstArchive(d), 'audiences')['presenceCount'] = 10;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('presences or passes kept for fewer than three present students', () {
      final d = document();
      firstOf(firstArchive(d), 'audiences')['studentCount'] = 2;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('more balls potted than attempted', () {
      final d = document();
      firstOf(firstArchive(d), 'exercises')['potted'] = 31;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a negative count and a count that is not an integer', () {
      for (final bad in <Object?>[-1, 1.5, '3']) {
        final d = document();
        firstOf(firstArchive(d), 'audiences')['sessionCount'] = bad;

        expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
      }
    });

    test('an unknown audience', () {
      final d = document();
      firstOf(firstArchive(d), 'audiences')['audience'] = 'seniors';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a missing field', () {
      final d = document();
      firstOf(firstArchive(d), 'exercises').remove('blockId');

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });
  });

  group('rules', () {
    Future<InvariantCode?> rulesCode(BackupSnapshot snapshot) async {
      final world = DomainWorld();
      final rules = BackupRules(
        world.catalogueRepository,
        FixtureSessionSheetRepository(catalogueFixture()),
        RulesConfig(),
        FixedClock(DateTime(2026, 10, 12, 18)),
      );
      try {
        await rules.check(snapshot);
      } on InvariantViolation catch (violation) {
        return violation.code;
      }
      return null;
    }

    BackupSnapshot withExercise(String block, int number) => _snapshot.copyWith(
      seasonArchives: [
        SeasonArchive(
          seasonId: const SeasonId('season'),
          audiences: const [],
          exercises: [
            ExerciseArchive(
              audience: Audience.children,
              exercise: ref(block, number),
              studentCount: 3,
              attemptCount: 1,
              potted: 1,
              total: 5,
            ),
          ],
        ),
      ],
    );

    test('accepts an archive on an exercise of the catalogue', () async {
      expect(await rulesCode(withExercise('a', 1)), isNull);
    });

    test('refuses an archive line on an unknown block', () async {
      expect(
        await rulesCode(withExercise('zzz', 1)),
        InvariantCode.backupUnknownBlock,
      );
    });

    test(
      'refuses an archive line on an exercise absent from its block',
      () async {
        expect(
          await rulesCode(withExercise('a', 4)),
          InvariantCode.backupInconsistent,
        );
      },
    );

    test(
      'accepts a planned session after the closing day of its season',
      () async {
        final group = Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('season'),
          name: 'Jeunes',
          audience: Audience.children,
        );
        final snapshot = _snapshot.copyWith(
          groups: [group],
          plannedSessions: [
            Session(
              id: 'p1',
              title: 'Rebond',
              date: day(20),
              audience: Audience.children,
              groupId: group.id,
            ),
          ],
        );

        expect(await rulesCode(snapshot), isNull);
      },
    );

    test(
      'still refuses a planned session before the start of the season',
      () async {
        final group = Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('season'),
          name: 'Jeunes',
          audience: Audience.children,
        );
        final snapshot = _snapshot.copyWith(
          groups: [group],
          plannedSessions: [
            Session(
              id: 'p1',
              title: 'Rebond',
              date: DateTime(2026, 9, 20),
              audience: Audience.children,
              groupId: group.id,
            ),
          ],
        );

        expect(await rulesCode(snapshot), InvariantCode.backupInvalid);
      },
    );
  });
}
