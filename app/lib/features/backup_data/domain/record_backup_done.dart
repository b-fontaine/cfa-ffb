import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_marker_repository.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : retenir qu'une sauvegarde vient d'être enregistrée (date et
/// nombre de passages du club à cet instant).
@injectable
class RecordBackupDone {
  RecordBackupDone(this._attempts, this._markers, this._clock);

  final AttemptRepository _attempts;
  final BackupMarkerRepository _markers;
  final Clock _clock;

  Future<Result<void>> call() => runGuarded(() async {
    await _markers.record((
      exportedAt: _clock.now(),
      attemptCount: (await _attempts.all()).length,
    ));
  });
}
