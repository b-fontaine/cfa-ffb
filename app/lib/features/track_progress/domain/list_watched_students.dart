import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_list.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Nombre d'élèves à surveiller montrés sur l'accueil par défaut.
const defaultWatchLimit = 5;

/// Cas d'usage : les élèves du club ayant une alerte active, une ligne par
/// élève (exercice le plus alarmant), dans l'ordre commun de
/// `compareWatched` (persistantes d'abord, échecs décroissants, identifiant).
/// Les passages sont lus une seule fois.
@injectable
class ListWatchedStudents {
  ListWatchedStudents(
    this._students,
    this._attempts,
    this._acquisitions,
    this._acknowledgements,
    this._catalogue,
    this._config,
  );

  final StudentRepository _students;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<WatchList>> call({int limit = defaultWatchLimit}) =>
      runGuarded(() async {
        final students = await _students.all();
        final catalogue = await _catalogue.load();
        final attempts = await _attempts.all();
        final acquisitions = await _acquisitions.all();
        final acknowledgements = await _acknowledgements.all();
        final progress = [
          for (final student in students)
            StudentProgress.derive(
              studentId: student.id,
              attempts: attempts,
              acquisitions: acquisitions,
              acknowledgements: acknowledgements,
              rates: catalogue.rates,
              config: _config,
            ),
        ];
        final byId = {for (final student in students) student.id: student};
        final watched = watchedStudents(
          progress,
          catalogueOrder: [for (final spec in catalogue.exercises) spec.ref],
        );
        // [watchedStudents] rend déjà l'ordre commun (compareWatched).
        final lines = [
          for (final entry in watched)
            WatchedLine(student: byId[entry.studentId]!, watched: entry),
        ];
        return WatchList(
          lines: List.unmodifiable(lines.take(limit)),
          total: lines.length,
          blockLabels: catalogue.blockLabels,
        );
      });
}
