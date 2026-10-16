import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : le résumé des 7 derniers jours du club (horloge injectée).
@injectable
class GetWeekSummary {
  GetWeekSummary(
    this._attempts,
    this._acquisitions,
    this._records,
    this._catalogue,
    this._config,
    this._clock,
  );

  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final SessionRecordRepository _records;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;
  final Clock _clock;

  Future<Result<WeekSummary>> call() => runGuarded(() async {
    final catalogue = await _catalogue.load();
    final attempts = await _attempts.all();
    final acquisitions = await _acquisitions.all();
    final studentIds = {for (final attempt in attempts) attempt.studentId};
    return weekSummary(
      today: _clock.today(),
      attempts: attempts,
      progress: [
        for (final student in studentIds)
          StudentProgress.derive(
            studentId: student,
            attempts: attempts,
            acquisitions: acquisitions,
            rates: catalogue.rates,
            config: _config,
          ),
      ],
      records: await _records.all(),
    );
  });
}
