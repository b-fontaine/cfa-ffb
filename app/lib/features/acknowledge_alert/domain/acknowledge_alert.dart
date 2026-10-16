import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : acquitter (« Vu ») l'alerte d'un élève sur un exercice
/// (ADR 0013).
///
/// L'acquittement est lié au dernier passage de l'exercice : il masque l'alerte
/// sur les surfaces de surveillance tant que ce passage reste le dernier. Il
/// n'est possible que sur une alerte active (non vue, exercice non acquis au
/// positionnement). Aucun passage n'est créé ni modifié.
@injectable
class AcknowledgeAlert {
  AcknowledgeAlert(
    this._students,
    this._attempts,
    this._acquisitions,
    this._acknowledgements,
    this._catalogue,
    this._ids,
    this._unitOfWork,
    this._config,
  );

  final StudentRepository _students;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;
  final CatalogueRepository _catalogue;
  final IdGenerator _ids;
  final UnitOfWork _unitOfWork;
  final RulesConfig _config;

  /// [today] date le « Vu » (normalisé au jour, horloge de l'appelant).
  Future<Result<AlertAcknowledgement>> call({
    required StudentId studentId,
    required ExerciseRef exercise,
    required DateTime today,
  }) => runGuarded(() async {
    if (await _students.byId(studentId) == null) {
      throw NotFound('student', studentId.value);
    }
    final catalogue = await _catalogue.load();
    if (catalogue.exercise(exercise) == null) {
      throw const InvariantViolation(InvariantCode.unknownExercise);
    }
    return await _unitOfWork.run(() async {
      final progress = StudentProgress.derive(
        studentId: studentId,
        attempts: await _attempts.forStudent(studentId),
        acquisitions: await _acquisitions.forStudent(studentId),
        acknowledgements: await _acknowledgements.forStudent(studentId),
        rates: catalogue.rates,
        config: _config,
      );
      final active = progress.activeAlerts
          .where((result) => result.exercise == exercise)
          .firstOrNull;
      if (active == null) {
        throw const InvariantViolation(InvariantCode.alertNotActive);
      }
      final acknowledgement = AlertAcknowledgement(
        id: AcknowledgementId(_ids.next()),
        studentId: studentId,
        exercise: exercise,
        lastAttemptId: active.lastAttempt!.id,
        date: today.dateOnly,
      );
      await _acknowledgements.add(acknowledgement);
      return acknowledgement;
    });
  });
}
