import 'dart:convert';

import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/json_reader.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/backup_formats.dart';
import '../../../support/fixtures.dart';

final _exportedAt = DateTime.utc(2026, 10, 12, 8);

final _season = Season(
  id: const SeasonId('season'),
  label: '2026-2027',
  startDate: DateTime(2026, 9),
  endDate: DateTime.utc(2027, 6, 30),
);

final _student = Student.enroll(
  id: const StudentId('s1'),
  firstName: 'Léa',
  audience: Audience.children,
  since: DateTime(2026, 9, 1, 14, 30, 15, 123, 456),
);

final Group _group =
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
        .release(studentId: const StudentId('s1'), to: DateTime(2027));

final _record = SessionRecord(
  id: const SessionId('x1'),
  groupId: const GroupId('g1'),
  seasonId: const SeasonId('season'),
  date: DateTime(2026, 10, 3),
  audience: Audience.children,
  present: {const StudentId('s1')},
  sheetId: SheetId('demi-bille-1'),
);

final _planned = Session(
  id: 'p1',
  title: 'Cours',
  date: DateTime(2026, 10, 19),
  audience: Audience.children,
  groupId: const GroupId('g1'),
  sheetId: SheetId('demi-bille-2'),
);

final _acquisition = BlockAcquisition(
  id: const AcquisitionId('q1'),
  studentId: const StudentId('s1'),
  blockId: 'puissance',
  date: DateTime(2026, 9, 15),
  source: AcquisitionSource.placement,
);

final _acknowledgement = AlertAcknowledgement(
  id: const AcknowledgementId('k1'),
  studentId: const StudentId('s1'),
  exercise: ref('a', 1),
  lastAttemptId: const AttemptId('a1'),
  date: DateTime(2026, 10, 5),
);

final _snapshot = BackupSnapshot(
  seasons: [_season],
  students: [_student],
  groups: [_group],
  sessionRecords: [_record],
  attempts: [attempt(ref('a', 1), potted: 3)],
  plannedSessions: [_planned],
  blockAcquisitions: [_acquisition],
  seasonArchives: const [],
  alertAcknowledgements: [_acknowledgement],
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

  test('writes the format, its own version and the export date', () {
    final document = jsonDecode(
      codec.encode(
        const BackupSnapshot(blockAcquisitions: [], seasonArchives: []),
        exportedAt: _exportedAt,
      ),
    ) as Map<String, Object?>;

    expect(document['format'], BackupCodec.format);
    expect(document['schemaVersion'], 5);
    expect(document['exportedAt'], '2026-10-12T08:00:00.000Z');
    expect(document['data'], {
      'seasons': <Object?>[],
      'students': <Object?>[],
      'groups': <Object?>[],
      'sessionRecords': <Object?>[],
      'attempts': <Object?>[],
      'assessments': <Object?>[],
      'plannedSessions': <Object?>[],
      'blockAcquisitions': <Object?>[],
      'alertAcknowledgements': <Object?>[],
      'seasonArchives': <Object?>[],
    });
  });

  test('writes the assessment comment and reads a file without it', () {
    final assessment = MaturityAssessment(
      id: const AssessmentId('m1'),
      studentId: const StudentId('s1'),
      date: DateTime(2026, 11),
      concentration: 3,
      endurance: 3,
      frustration: 2,
      comment: 'Calme',
    );
    final content = codec.encode(
      _snapshot.copyWith(assessments: [assessment]),
      exportedAt: _exportedAt,
    );
    final document = jsonDecode(content) as Map<String, Object?>
      ..['schemaVersion'] = 1;
    (document['data']! as Map<String, Object?>)
      ..remove('alertAcknowledgements')
      ..remove('seasonArchives');
    dropSessionTags(document['data']! as Map<String, Object?>);
    final stored =
        ((document['data']! as Map<String, Object?>)['assessments']!
                    as List<Object?>)
                .single!
            as Map<String, Object?>;

    expect(stored['comment'], 'Calme');
    expect(codec.decode(content).assessments.single, assessment);

    stored.remove('comment');
    expect(
      codec.decode(jsonEncode(document)).assessments.single,
      assessment.copyWith(comment: null),
    );
  });

  test('writes the acquired blocks with their day, source and student', () {
    final document = jsonDecode(
      codec.encode(_snapshot, exportedAt: _exportedAt),
    ) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;

    expect((data['blockAcquisitions']! as List<Object?>).single, {
      'id': 'q1',
      'studentId': 's1',
      'blockId': 'puissance',
      'date': '2026-09-15T00:00:00.000',
      'source': 'placement',
    });
    expect(
      codec
          .decode(codec.encode(_snapshot, exportedAt: _exportedAt))
          .blockAcquisitions,
      [_acquisition],
    );
  });

  test('exposes the supported versions', () {
    expect(BackupCodec.currentVersion, 5);
    expect(BackupCodec.supportedVersions, {1, 2, 3, 4, 5});
  });

  group('session tags (format 5, ADR 0023)', () {
    Map<String, Object?> exported({Set<SessionTag> tags = const {}}) =>
        jsonDecode(
          codec.encode(
            _snapshot.copyWith(sessionRecords: [_record.copyWith(tags: tags)]),
            exportedAt: _exportedAt,
          ),
        ) as Map<String, Object?>;

    Map<String, Object?> recordOf(Map<String, Object?> document) =>
        ((document['data']! as Map<String, Object?>)['sessionRecords']!
                    as List<Object?>)
                .single!
            as Map<String, Object?>;

    test('writes the codes in display order, an empty list when none', () {
      expect(
        recordOf(
          exported(tags: {SessionTag.toRedo, SessionTag.tooLong}),
        )['tags'],
        ['tooLong', 'toRedo'],
      );
      expect(recordOf(exported())['tags'], <Object?>[]);
    });

    test('round-trips the tags of a session', () {
      final tags = {SessionTag.gameAppreciated, SessionTag.equipmentLacking};
      final content = codec.encode(
        _snapshot.copyWith(sessionRecords: [_record.copyWith(tags: tags)]),
        exportedAt: _exportedAt,
      );

      expect(codec.decode(content).sessionRecords.single.tags, tags);
    });

    test('reads a file of format 4 as having no tags', () {
      final document = exported()..['schemaVersion'] = 4;
      recordOf(document).remove('tags');

      expect(codec.decode(jsonEncode(document)).sessionRecords.single, _record);
    });

    test('refuses a tags key in a file of format 4', () {
      final document = exported(tags: {SessionTag.tooLong})
        ..['schemaVersion'] = 4;

      expect(_codeOf(jsonEncode(document)), InvariantCode.backupInvalid);
    });

    test('requires the tags key in a file of format 5', () {
      final document = exported();
      recordOf(document).remove('tags');

      expect(_codeOf(jsonEncode(document)), InvariantCode.backupInvalid);
    });

    for (final (label, value) in <(String, Object?)>[
      ('an unknown code', ['inconnue']),
      ('free text', ['Hugo a été pénible']),
      ('a duplicated code', ['tooLong', 'tooLong']),
      ('something that is not a list', 'tooLong'),
      ('a non-string item', [3]),
      ('null', null),
    ]) {
      test('refuses $label', () {
        final document = exported();
        recordOf(document)['tags'] = value;

        expect(_codeOf(jsonEncode(document)), InvariantCode.backupInvalid);
      });
    }
  });

  test(
    'writes the alert acknowledgements with their exercise and last pass',
    () {
      final document = jsonDecode(
        codec.encode(_snapshot, exportedAt: _exportedAt),
      ) as Map<String, Object?>;
      final data = document['data']! as Map<String, Object?>;

      expect((data['alertAcknowledgements']! as List<Object?>).single, {
        'id': 'k1',
        'studentId': 's1',
        'blockId': 'a',
        'exerciseNumber': 1,
        'lastAttemptId': 'a1',
        'date': '2026-10-05T00:00:00.000',
      });
      expect(
        codec
            .decode(codec.encode(_snapshot, exportedAt: _exportedAt))
            .alertAcknowledgements,
        [_acknowledgement],
      );
    },
  );

  test('reads a file of format 2 as having no acknowledgement list', () {
    final document = jsonDecode(
      codec.encode(_snapshot, exportedAt: _exportedAt),
    ) as Map<String, Object?>;
    document['schemaVersion'] = 2;
    (document['data']! as Map<String, Object?>)
      ..remove('alertAcknowledgements')
      ..remove('seasonArchives');
    dropSessionTags(document['data']! as Map<String, Object?>);

    expect(codec.decode(jsonEncode(document)).alertAcknowledgements, isNull);
  });

  test(
    'a snapshot without acknowledgement list is written as an empty one',
    () {
      final content = codec.encode(
        _snapshot.copyWith(alertAcknowledgements: null),
        exportedAt: _exportedAt,
      );

      expect(codec.decode(content).alertAcknowledgements, isEmpty);
    },
  );

  test('writes the settings only when the snapshot has some', () {
    const settings = ClubSettings(
      passesRequired: 3,
      alertThreshold: 4,
      recallStaleSessions: 6,
      groupFailureSharePercent: 30,
      backupReminderDays: 14,
    );

    final content = codec.encode(
      const BackupSnapshot(
        blockAcquisitions: [],
        seasonArchives: [],
        settings: settings,
      ),
      exportedAt: _exportedAt,
    );

    final data =
        (jsonDecode(content) as Map<String, Object?>)['data']!
            as Map<String, Object?>;
    expect(data['settings'], {
      'passesRequired': 3,
      'alertThreshold': 4,
      'recallStaleSessions': 6,
      'groupFailureSharePercent': 30,
      'backupReminderDays': 14,
    });
    expect(codec.decode(content).settings, settings);
    final without = codec.encode(
      const BackupSnapshot(blockAcquisitions: [], seasonArchives: []),
      exportedAt: _exportedAt,
    );
    expect(
      ((jsonDecode(without) as Map<String, Object?>)['data']!
              as Map<String, Object?>)
          .containsKey('settings'),
      isFalse,
    );
    expect(codec.decode(without).settings, isNull);
  });

  test('still reads a file of format 1, which has no settings', () {
    final document = jsonDecode(
      codec.encode(
        const BackupSnapshot(blockAcquisitions: [], seasonArchives: []),
        exportedAt: _exportedAt,
      ),
    ) as Map<String, Object?>;
    document['schemaVersion'] = 1;
    (document['data']! as Map<String, Object?>)
      ..remove('alertAcknowledgements')
      ..remove('seasonArchives');

    expect(codec.decode(jsonEncode(document)).settings, isNull);
  });

  test('round-trips every entity with exact dates and UTC flags', () {
    final content = codec.encode(_snapshot, exportedAt: _exportedAt);

    final decoded = codec.decode(content);

    expect(decoded, _snapshot);
    expect(decoded.seasons.single.endDate.isUtc, isTrue);
    expect(decoded.seasons.single.startDate.isUtc, isFalse);
    expect(
      decoded
          .students
          .single
          .audienceHistory
          .single
          .effectiveFrom
          .microsecondsSinceEpoch,
      DateTime(2026, 9, 1, 14, 30, 15, 123, 456).microsecondsSinceEpoch,
    );
  });

  test('writes the planned date and group and the recorded sheet', () {
    final document = jsonDecode(
      codec.encode(_snapshot, exportedAt: _exportedAt),
    ) as Map<String, Object?>;
    final data = document['data']! as Map<String, Object?>;
    final planned =
        (data['plannedSessions']! as List<Object?>).single!
            as Map<String, Object?>;
    final record =
        (data['sessionRecords']! as List<Object?>).single!
            as Map<String, Object?>;

    expect(planned['date'], '2026-10-19T00:00:00.000');
    expect(planned['groupId'], 'g1');
    expect(planned['sheetId'], 'demi-bille-2');
    expect(record['sheetId'], 'demi-bille-1');
  });

  test('reads a planned session without group and a record without sheet', () {
    final free = _planned.copyWith(groupId: null, sheetId: null);
    final content = codec.encode(
      _snapshot.copyWith(
        plannedSessions: [free],
        sessionRecords: [_record.copyWith(sheetId: null)],
      ),
      exportedAt: _exportedAt,
    );

    final decoded = codec.decode(content);

    expect(decoded.plannedSessions.single, free);
    expect(decoded.sessionRecords.single.sheetId, isNull);
  });

  test('writes open memberships with a null end and keeps closed ones', () {
    final document = jsonDecode(
      codec.encode(_snapshot, exportedAt: _exportedAt),
    ) as Map<String, Object?>;
    final groups =
        (document['data']! as Map<String, Object?>)['groups']! as List<Object?>;
    final memberships =
        (groups.single! as Map<String, Object?>)['memberships']!
            as List<Object?>;

    expect((memberships.single! as Map<String, Object?>)['to'], isNotNull);
  });

  test('accepts a file whose version is the current one', () {
    final content = codec.encode(_snapshot, exportedAt: _exportedAt);

    expect(() => codec.decode(content), returnsNormally);
  });

  group('refuses', () {
    Map<String, Object?> document() =>
        jsonDecode(codec.encode(_snapshot, exportedAt: _exportedAt))
            as Map<String, Object?>;
    Map<String, Object?> data(Map<String, Object?> d) =>
        d['data']! as Map<String, Object?>;
    Map<String, Object?> first(Map<String, Object?> d, String key) =>
        (data(d)[key]! as List<Object?>).first! as Map<String, Object?>;

    test('a file larger than the maximum, before decoding it', () {
      final content = ' ' * (BackupCodec.maxContentLength + 1);

      expect(_codeOf(content), InvariantCode.backupUnreadable);
    });

    test('a file just at the maximum size is still parsed', () {
      final content = ' ' * BackupCodec.maxContentLength;

      expect(_codeOf(content), InvariantCode.backupUnreadable);
      expect(
        () => codec.decode(content),
        throwsA(isA<InvariantViolation>()),
        reason: 'refused as unreadable JSON, not as too large',
      );
    });

    test('a document nested deeper than the maximum depth', () {
      const depth = BackupCodec.maxDepth + 1;
      final content = '${'[' * depth}${']' * depth}';

      expect(_codeOf(content), InvariantCode.backupUnreadable);
    });

    test('a very deep document without overflowing the stack', () {
      final content = '${'[' * 200000}${']' * 200000}';

      expect(_codeOf(content), InvariantCode.backupUnreadable);
    });

    test('brackets inside strings do not count as depth', () {
      final d = document()
        ..['note'] = '[' * (BackupCodec.maxDepth * 4)
        ..['other'] = r'\"[[[[[[[[[[[[[[[[[[[[';

      expect(() => codec.decode(jsonEncode(d)), returnsNormally);
    });

    test('a string longer than the maximum length', () {
      final d = document();
      first(d, 'students')['firstName'] =
          'x' * (JsonReader.maxStringLength + 1);

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a string exactly at the maximum length', () {
      final d = document();
      first(d, 'groups')['name'] = 'x' * JsonReader.maxStringLength;

      expect(() => codec.decode(jsonEncode(d)), returnsNormally);
    });

    test('a list exactly at the maximum number of items', () {
      final items = List<Object?>.filled(JsonReader.maxItems, 1);

      expect(const JsonReader().list(items), hasLength(JsonReader.maxItems));
    });

    test('a list with more items than the maximum', () {
      final d = document();
      data(d)['plannedSessions'] = List<Object?>.filled(
        JsonReader.maxItems + 1,
        <String, Object?>{},
      );

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a root that is not an object', () {
      expect(_codeOf('[]'), InvariantCode.backupUnreadable);
      expect(_codeOf('"texte"'), InvariantCode.backupUnreadable);
    });

    test('another format name', () {
      final d = document()..['format'] = 'autre';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupUnreadable);
    });

    test('a non-integer version', () {
      final d = document()..['schemaVersion'] = 1.5;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupVersionUnsupported);
    });

    test('a data section that is not an object', () {
      final d = document()..['data'] = <Object?>[];

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a list that is not a list', () {
      final d = document();
      data(d)['students'] = 'Léa';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a list item that is not an object', () {
      final d = document();
      data(d)['students'] = [1];

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a fractional number', () {
      final d = document();
      first(d, 'attempts')['potted'] = 3.5;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a number stored as text', () {
      final d = document();
      first(d, 'attempts')['total'] = '5';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a presence that is not an identifier', () {
      final d = document();
      first(d, 'sessionRecords')['present'] = [3];

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a block identifier that is not text', () {
      final d = document();
      first(d, 'sessionRecords')['mainBlockId'] = 4;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a membership end that is not a date', () {
      final d = document();
      final memberships = first(d, 'groups')['memberships']! as List<Object?>;
      (memberships.single! as Map<String, Object?>)['to'] = 'jamais';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('a file without the blockAcquisitions key', () {
      final d = document();
      data(d).remove('blockAcquisitions');

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an acquired block with an unknown source', () {
      final d = document();
      first(d, 'blockAcquisitions')['source'] = 'magie';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an acquired block with a missing field', () {
      final d = document();
      first(d, 'blockAcquisitions').remove('blockId');

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an acquired block whose date is not a whole day', () {
      final d = document();
      first(d, 'blockAcquisitions')['date'] = '2026-09-15T10:30:00.000';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('the same block acquired twice for a student', () {
      final d = document();
      (data(d)['blockAcquisitions']! as List<Object?>).add({
        ...first(d, 'blockAcquisitions'),
        'id': 'q2',
      });

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('an acquired block of an unknown student', () {
      final d = document();
      first(d, 'blockAcquisitions')['studentId'] = 'ghost';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('acknowledgements in a file of format 1 or 2', () {
      for (final version in [1, 2]) {
        final d = document()..['schemaVersion'] = version;
        data(d).remove('seasonArchives');

        expect(
          _codeOf(jsonEncode(d)),
          InvariantCode.backupInvalid,
          reason: 'format $version ne connaît pas la clé',
        );
      }
    });

    test('a file of format 4 without the alertAcknowledgements key', () {
      final d = document();
      data(d).remove('alertAcknowledgements');

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an acknowledgement with a missing field', () {
      final d = document();
      first(d, 'alertAcknowledgements').remove('lastAttemptId');

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an acknowledgement whose date is not a whole day', () {
      final d = document();
      first(d, 'alertAcknowledgements')['date'] = '2026-10-05T10:30:00.000';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an acknowledgement with an invalid exercise number', () {
      final d = document();
      first(d, 'alertAcknowledgements')['exerciseNumber'] = 0;

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });

    test('an acknowledgement of an unknown student', () {
      final d = document();
      first(d, 'alertAcknowledgements')['studentId'] = 'ghost';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('two acknowledgements with the same identifier', () {
      final d = document();
      (data(d)['alertAcknowledgements']! as List<Object?>).add({
        ...first(d, 'alertAcknowledgements'),
        'exerciseNumber': 2,
      });

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInconsistent);
    });

    test('a membership closed before it opens', () {
      final d = document();
      final memberships = first(d, 'groups')['memberships']! as List<Object?>;
      (memberships.single! as Map<String, Object?>)['to'] =
          '2020-01-01T00:00:00.000';

      expect(_codeOf(jsonEncode(d)), InvariantCode.backupInvalid);
    });
  });

  test('reads optional block identifiers and open memberships', () {
    final record = SessionRecord(
      id: const SessionId('x1'),
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      date: DateTime(2026, 10, 3),
      audience: Audience.adults,
      present: {const StudentId('s1')},
      mainBlockId: 'puissance',
      recallBlockId: 'rebond',
    );
    final open =
        Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('season'),
          name: 'Adultes',
          audience: Audience.adults,
        ).admit(
          studentId: const StudentId('s1'),
          studentAudience: Audience.adults,
          from: DateTime(2026, 9),
        );
    final snapshot = _snapshot.copyWith(
      sessionRecords: [record],
      groups: [open],
    );

    final decoded = codec.decode(
      codec.encode(snapshot, exportedAt: _exportedAt),
    );

    expect(decoded.sessionRecords.single.mainBlockId, 'puissance');
    expect(decoded.sessionRecords.single.recallBlockId, 'rebond');
    expect(decoded.groups.single.memberships.single.to, isNull);
  });
}
