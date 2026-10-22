import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';

/// Un magasin d'opérations **sans Firestore** : un seul marqueur en mémoire,
/// avec la règle que les règles du serveur imposent (création à `done == 1`,
/// avancement d'exactement un lot, suppression à la fin), et des coupures
/// programmables. Sert les tests du moteur, qui ne savent rien d'un stockage.
class FakeOperationStore implements OperationStore {
  OperationMarker? marker;

  /// Les lots appliqués (dans l'ordre) : le nom que leur donne l'opération.
  final List<String> applied = [];

  /// Après ce nombre de lots appliqués, le lot suivant échoue (`unavailable`).
  int? failAfter;

  /// Le prochain lot échoue avec ce code, sans être appliqué.
  ServiceFailureCode? failNextWith;

  /// Le prochain lot est appliqué **ailleurs** avant d'être refusé ici : un
  /// autre appareil a avancé le marqueur d'un lot (et, avec `true`, fini).
  void Function()? elsewhere;

  @override
  Future<OperationMarker?> readMarker(String key) async => marker;

  @override
  Future<List<OperationMarker>> ownMarkers() async => [?marker];

  @override
  Future<void> commit(OperationLotCommit commit) async {
    final cut = failAfter;
    if (cut != null && applied.length >= cut) {
      throw const ServiceFailure(ServiceFailureCode.unavailable, 'coupure');
    }
    final code = failNextWith;
    if (code != null) {
      failNextWith = null;
      throw ServiceFailure(code, 'refus simulé');
    }
    final other = elsewhere;
    if (other != null) {
      elsewhere = null;
      other();
    }
    final current = marker;
    if (commit.createsMarker) {
      if (current != null) {
        throw const ServiceFailure(ServiceFailureCode.denied, 'existe déjà');
      }
    } else if (current == null || commit.marker.done != current.done + 1) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'avancement');
    }
    await commit.lot.apply();
    marker = commit.finishes ? null : commit.marker;
    applied.add('lot-${applied.length + 1}');
  }
}
