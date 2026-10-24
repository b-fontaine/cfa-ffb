import 'package:billard_cfa/app/firestore_stale_marker_store.dart';
import 'package:billard_cfa/app/import_daily_ledger_adapter.dart';
import 'package:billard_cfa/features/backup_data/data/key_value_import_daily_ledger.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_cubit.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:injectable/injectable.dart';

/// Câblage de la purge des marqueurs abandonnés (FB8 partie B, B5). Les
/// marqueurs vivent toujours dans Firestore (le stock de documents des
/// comptes et des clubs), quel que soit le backend des données du club, comme
/// le nettoyage par l'auteur (`AccountDeletionModule`). Le plafond du jour est
/// **le même compteur** que celui de l'import et des opérations reprenables
/// (`ImportDailyLedger`, par compte et par appareil).
@module
abstract class StaleMarkersModule {
  /// Le compteur du jour pour les scénarios et les tests du routeur
  /// (`Environment.test`) : la même réalisation qu'en production
  /// (`KeyValueImportDailyLedger`, enregistrée pour `prod` seulement), sur le
  /// `KeyValueStore` du test, pour que « Mon club » s'ouvre aussi en test.
  @Environment(Environment.test)
  @lazySingleton
  ImportDailyLedger testImportDailyLedger(
    KeyValueStore store,
    Clock clock,
    CurrentUser user,
  ) => KeyValueImportDailyLedger(store, clock, user);

  @lazySingleton
  StaleMarkerStore staleMarkerStore(DocumentStore documents) =>
      FirestoreStaleMarkerStore(documents);

  @lazySingleton
  PurgeStaleMarkers purgeStaleMarkers(
    StaleMarkerStore store,
    ImportDailyLedger ledger,
    Clock clock,
    ActiveClubScope scope,
  ) => PurgeStaleMarkers(store, ImportDailyLedgerAdapter(ledger), clock, scope);

  @injectable
  StaleMarkersCubit staleMarkersCubit(PurgeStaleMarkers purge) =>
      StaleMarkersCubit(purge.call);
}
