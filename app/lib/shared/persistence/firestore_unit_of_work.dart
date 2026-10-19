import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Unité de travail Firestore : un `WriteBatch` (ADR 0024, décision 19).
///
/// Les écritures que les dépôts Firestore font pendant `run` (même zone)
/// attendent la fin du corps, puis partent en **un seul lot atomique** : tout
/// ou rien, y compris si le corps échoue ou si une écriture est refusée. Un
/// dépôt y relit ses propres écritures (`ClubStore.get`). Au plus 500
/// écritures : au-delà, `ServiceFailure` explicite (`500` écritures) avant
/// toute écriture. **Limites connues** : `CloseSeason` passe encore par `run` ;
/// avec ce backend, un club de plus de 500 écritures ne peut pas clore une
/// saison, et les lectures de liste n'y voient pas les écritures en attente.
/// `ImportBackup` n'y est **pas supporté** avant FB7 : une saisie se crée par
/// transaction (`ClubStore.createIfAbsent`), refusée dans une unité par
/// `ServiceFailure` `unsupported`, sans rien écrire. Les lots reprenables de la
/// décision 19 (FB7, FB8) les en sortiront : **bloquant de bascule** (ADR
/// 0024, notes FB4b).
///
/// **Hors ligne** : `commit` n'est acquitté qu'à la réponse du serveur, qui ne
/// vient pas hors ligne. Avec un [SendTracker] (le montage de
/// `CompositeUnitOfWork`), `run` **n'attend pas cet accusé** : le SDK applique
/// le lot à son cache dès l'appel, l'unité se termine (la transaction drift se
/// ferme, aucune écriture locale n'est bloquée) et l'envoi est suivi à part
/// (`SendStatus`, ADR 0024, notes FB4c). La taille du lot est vérifiée avant
/// l'envoi ; un refus du serveur arrive après coup dans
/// `SendStatus.hasFailure` (détail : `SendTracker.lastFailure`).
///
/// Les dépôts qui ne sont pas encore sur Firestore (drift) n'y participent
/// pas : voir `CompositeUnitOfWork`.
class FirestoreUnitOfWork implements UnitOfWork {
  FirestoreUnitOfWork(this._club, {this.tracker});

  final ClubStore _club;

  /// Avec un suivi, le lot est **validé localement sans attendre l'accusé du
  /// serveur** (voir ci-dessus) ; sans suivi, `run` attend le serveur.
  final SendTracker? tracker;

  @override
  Future<T> run<T>(Future<T> Function() body) =>
      guardStore(() => _club.atomically(body, onSend: tracker?.track));
}
