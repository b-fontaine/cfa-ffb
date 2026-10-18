import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux passages (implémenté dans la couche data).
///
/// Un passage est **un document** (ADR 0024, décision 17). Les lectures
/// renvoient l'**ordre d'enregistrement** (drift et mémoire : l'insertion ;
/// Firestore : `createdAt` du serveur, puis `recordedAt` de l'appareil,
/// puis identifiant) : c'est lui qui
/// départage les passages d'une même date et dont se dérive le rang d'un
/// passage (`chronological`, `passRanks`). Rien n'est renuméroté.
abstract interface class AttemptRepository {
  /// Enregistre un **nouveau** passage (identifiant neuf). Rejouer un
  /// identifiant déjà connu remplace le passage sur drift et en mémoire (c'est
  /// ce qui rend l'import d'une sauvegarde idempotent) ; Firestore ne le
  /// permet pas (ajout seul : une écriture sur un passage existant est une
  /// correction, voir [correct]).
  Future<void> add(ExerciseAttempt attempt);

  /// Corrige **en place** les billes empochées et les tentatives d'un passage
  /// existant (ADR 0006) ; l'élève, la séance, l'exercice, la date et l'ordre
  /// d'enregistrement ne changent pas. `NotFound` si le passage n'existe pas.
  Future<void> correct(ExerciseAttempt attempt);

  Future<List<ExerciseAttempt>> forStudent(StudentId studentId);

  Future<List<ExerciseAttempt>> forSession(SessionId sessionId);

  Future<List<ExerciseAttempt>> all();

  /// Supprime le passage ; sans effet s'il n'existe pas (logique sur drift,
  /// physique sur Firestore, décision 15).
  Future<void> delete(AttemptId id);

  /// Efface physiquement tous les passages de l'élève (droit à l'effacement),
  /// y compris ceux supprimés logiquement.
  Future<void> eraseStudent(StudentId studentId);
}
