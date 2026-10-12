import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux séances données (implémenté dans la couche data).
///
/// Même contrat que `StudentRepository` : ordre de première sauvegarde pour
/// [all], remplacement par id, suppression logique.
abstract interface class SessionRecordRepository {
  Future<void> save(SessionRecord session);

  Future<SessionRecord?> byId(SessionId id);

  /// Séances d'un groupe, de la plus ancienne à la plus récente.
  Future<List<SessionRecord>> forGroup(GroupId groupId);

  /// Séances où l'élève était présent, de la plus ancienne à la plus récente.
  Future<List<SessionRecord>> forStudent(StudentId studentId);

  Future<List<SessionRecord>> all();

  /// Supprime logiquement la séance ; sans effet si elle n'existe pas.
  Future<void> delete(SessionId id);

  /// Efface physiquement la présence de l'élève dans toutes les séances
  /// (droit à l'effacement) ; les séances elles-mêmes restent.
  Future<void> eraseStudent(StudentId studentId);
}
