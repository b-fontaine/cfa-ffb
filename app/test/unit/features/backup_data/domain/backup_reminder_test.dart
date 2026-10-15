import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_marker_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/domain/check_backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/domain/record_backup_done.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixed_clock.dart';
import '../../../../support/fixtures.dart' as fx;

final _now = DateTime(2026, 10, 12, 9, 30);
ExerciseAttempt _attempt(String id) =>
    fx.attempt(ExerciseRef(blockId: 'puissance', number: 1), potted: 3, id: id);

final _backup = DateTime(2026, 9, 12, 18);

BackupReminder _rule({
  required int attempts,
  DateTime? backupAt,
  int backupAttempts = 0,
}) => BackupReminder.evaluate(
  now: _now,
  attemptCount: attempts,
  last: backupAt == null
      ? null
      : (exportedAt: backupAt, attemptCount: backupAttempts),
);

void main() {
  group('BackupReminder.evaluate', () {
    test('stays silent before the first pass is entered', () {
      expect(_rule(attempts: 0), isA<NoBackupReminder>());
      expect(
        _rule(attempts: 0, backupAt: DateTime(2026)),
        isA<NoBackupReminder>(),
      );
    });

    test('reminds that entered passes were never backed up', () {
      expect(_rule(attempts: 4), isA<NeverBackedUp>());
    });

    test('reminds the passes entered since the last backup', () {
      final reminder = _rule(
        attempts: 7,
        backupAt: DateTime(2026, 10, 10),
        backupAttempts: 4,
      );

      expect(reminder, isA<NewPassesSinceBackup>());
      expect((reminder as NewPassesSinceBackup).count, 3);
    });

    test('is silent when a recent backup holds every pass', () {
      expect(
        _rule(attempts: 4, backupAt: DateTime(2026, 10, 10), backupAttempts: 4),
        isA<NoBackupReminder>(),
      );
    });

    test('is silent when passes were only deleted since the backup', () {
      expect(
        _rule(attempts: 3, backupAt: DateTime(2026, 10, 10), backupAttempts: 4),
        isA<NoBackupReminder>(),
      );
    });

    test('is silent at 29 days and reminds from 30 days', () {
      expect(
        _rule(attempts: 4, backupAt: DateTime(2026, 9, 13), backupAttempts: 4),
        isA<NoBackupReminder>(),
      );

      final reminder = _rule(
        attempts: 4,
        backupAt: DateTime(2026, 9, 12, 23),
        backupAttempts: 4,
      );

      expect(reminder, isA<StaleBackup>());
      expect((reminder as StaleBackup).days, 30);
    });

    test('prefers the age when the backup is old and passes are new', () {
      expect(
        _rule(attempts: 9, backupAt: _backup, backupAttempts: 4),
        isA<StaleBackup>(),
      );
    });
  });

  group('use cases', () {
    late InMemoryAttemptRepository attempts;
    late InMemoryBackupMarkerRepository markers;
    late FixedClock clock;

    setUp(() {
      attempts = InMemoryAttemptRepository();
      markers = InMemoryBackupMarkerRepository();
      clock = FixedClock(_now);
    });

    CheckBackupReminder check() =>
        CheckBackupReminder(attempts, markers, clock);

    test('check is silent on an empty club', () async {
      expect(await check()(), isA<NoBackupReminder>());
    });

    test('is silent right after a backup that holds every pass', () async {
      await attempts.add(_attempt('a1'));
      await RecordBackupDone(attempts, markers, clock)();

      expect(await check()(), isA<NoBackupReminder>());
    });

    test('reminds never backed up before any backup', () async {
      await attempts.add(_attempt('a1'));

      expect(await check()(), isA<NeverBackedUp>());
    });

    test('counts the passes entered after a backup', () async {
      await attempts.add(_attempt('a1'));
      await RecordBackupDone(attempts, markers, clock)();
      await attempts.add(_attempt('a2'));

      final reminder = await check()();

      expect((reminder as NewPassesSinceBackup).count, 1);
    });

    test('reminds the age of a backup 31 days old', () async {
      await attempts.add(_attempt('a1'));
      await RecordBackupDone(attempts, markers, clock)();
      clock.advance(const Duration(days: 31));

      final reminder = await check()();

      expect((reminder as StaleBackup).days, 31);
    });
  });
}
