import 'package:billard_cfa/shared/persistence/change_feed.dart';
import 'package:drift/drift.dart';

/// Les `watch…` des dépôts drift.
extension DriftWatch on GeneratedDatabase {
  /// Relit `read` au départ puis à chaque écriture validée dans l'une des
  /// `tables` (de cette application ou d'un autre onglet qui partage la base :
  /// drift l'annonce). Une transaction n'annonce qu'à sa validation : un
  /// abonné ne voit jamais un état à moitié écrit. Voir `watchRead`.
  Stream<T> watchTables<T>(
    List<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() read,
  ) => watchRead(
    tableUpdates(TableUpdateQuery.onAllTables(tables)).map((_) {}),
    read,
  );
}
