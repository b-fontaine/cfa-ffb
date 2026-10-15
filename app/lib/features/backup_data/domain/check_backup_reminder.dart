import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_marker_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : faut-il rappeler la sauvegarde ? (horloge injectée)
@injectable
class CheckBackupReminder {
  CheckBackupReminder(this._attempts, this._markers, this._clock);

  final AttemptRepository _attempts;
  final BackupMarkerRepository _markers;
  final Clock _clock;

  Future<BackupReminder> call() async => BackupReminder.evaluate(
    now: _clock.now(),
    attemptCount: (await _attempts.all()).length,
    last: await _markers.last(),
  );
}
