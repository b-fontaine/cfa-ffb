import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux passages (implémenté dans la couche data).
///
/// Les lectures renvoient l'ordre d'enregistrement ; [add] d'un id déjà connu
/// remplace le passage (idempotent) ; la suppression est logique.
abstract interface class AttemptRepository {
  Future<void> add(ExerciseAttempt attempt);

  Future<List<ExerciseAttempt>> forStudent(StudentId studentId);

  Future<List<ExerciseAttempt>> forSession(SessionId sessionId);

  Future<List<ExerciseAttempt>> all();

  /// Supprime logiquement le passage ; sans effet s'il n'existe pas.
  Future<void> delete(AttemptId id);

  /// Efface physiquement tous les passages de l'élève (droit à l'effacement),
  /// y compris ceux supprimés logiquement.
  Future<void> eraseStudent(StudentId studentId);
}
