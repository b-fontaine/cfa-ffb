import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux acquittements d'alertes (implémenté dans la couche data).
///
/// [add] d'un id déjà connu remplace l'acquittement (idempotent) ; la
/// suppression est logique.
abstract interface class AcknowledgementRepository {
  Future<void> add(AlertAcknowledgement acknowledgement);

  /// Acquittements de l'élève, du plus ancien au plus récent.
  Future<List<AlertAcknowledgement>> forStudent(StudentId studentId);

  /// Tous les acquittements, dans l'ordre d'enregistrement.
  Future<List<AlertAcknowledgement>> all();

  /// Supprime logiquement l'acquittement ; sans effet s'il n'existe pas.
  Future<void> delete(AcknowledgementId id);

  /// Efface physiquement tous les acquittements de l'élève (droit à
  /// l'effacement), y compris ceux supprimés logiquement.
  Future<void> eraseStudent(StudentId studentId);

  /// Efface physiquement tous les acquittements du club (import d'une
  /// sauvegarde d'un format qui ne les connaît pas, ADR 0013).
  Future<void> eraseAll();

  /// Suit les « Vu » d'un élève (voir [forStudent] ; contrat des `watch…` :
  /// `StudentRepository.watchById`). Partagé par club : l'acquittement d'un
  /// animateur arrive chez les autres.
  Stream<List<AlertAcknowledgement>> watchForStudent(StudentId studentId);

  /// Suit tous les « Vu » du club (voir [all]).
  Stream<List<AlertAcknowledgement>> watchAll();
}
