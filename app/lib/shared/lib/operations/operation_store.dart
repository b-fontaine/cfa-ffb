import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';

/// Un lot à écrire avec l'avancement du marqueur qui l'accompagne.
final class OperationLotCommit {
  const OperationLotCommit({
    required this.lot,
    required this.marker,
    required this.createsMarker,
    required this.finishes,
  });

  final OperationLot lot;

  /// Le marqueur **après** ce lot (`done` + 1).
  final OperationMarker marker;

  /// Premier lot de l'opération : le marqueur est créé (sinon, avancé d'un
  /// lot).
  final bool createsMarker;

  /// Dernier lot : le marqueur est **supprimé** dans le même lot atomique.
  final bool finishes;
}

/// Le club, vu par une opération reprenable : le marqueur de **son auteur** et
/// l'écriture atomique d'un lot. Implémenté pour Firestore par
/// `FirestoreOperationStore` ; un double en mémoire sert les tests.
abstract interface class OperationStore {
  /// Le marqueur de l'opération [key] pour le compte courant, relu **au
  /// serveur** (jamais un cache) ; `null` s'il n'existe pas. Lève
  /// `ServiceFailure` `unavailable` hors ligne.
  Future<OperationMarker?> readMarker(String key);

  /// Les marqueurs du compte courant (reprise d'une clôture dont on ne
  /// connaît que l'auteur), relus au serveur.
  Future<List<OperationMarker>> ownMarkers();

  /// Applique **en un seul lot atomique** les écritures du lot et le
  /// marqueur (création, avancement d'un lot, ou suppression si
  /// [OperationLotCommit.finishes]). Lève `ServiceFailure` : `unavailable`
  /// (réseau), `denied` (règles : le marqueur n'était plus celui attendu, ou
  /// un droit manque), `other`.
  Future<void> commit(OperationLotCommit commit);
}

/// Les écritures déjà faites **aujourd'hui** sur cet appareil par ce compte :
/// l'état qui fait tenir le plafond quotidien entre deux exécutions.
abstract interface class DailyWriteLedger {
  /// Écritures comptées aujourd'hui (zéro un autre jour).
  Future<int> spentToday();

  /// Ajoute [writes] au compte d'aujourd'hui.
  Future<void> add(int writes);
}
