import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/firestore_club_import_store.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/prepare_club_import.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_import_daily_ledger.dart';
import 'ui_world.dart';

/// L'application complète **sous le backend du club**
/// (`DATA_BACKEND=firestore`) pour l'écran d'import : l'aiguillage de « Plus »
/// lit le backend retenu, et le cubit d'import est monté sur les dépôts de la
/// scène.
Future<void> useClubBackendForImport(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  final graph = getIt;
  if (graph.isRegistered<DataBackendChoice>()) {
    await graph.unregister<DataBackendChoice>();
  }
  graph.registerSingleton<DataBackendChoice>(
    const DataBackendChoice(DataBackend.firestore),
  );
  final scope = graph<ActiveClubScope>();
  final store = FirestoreClubImportStore(
    graph<ClubStore>(),
    graph<CurrentUser>(),
  );
  graph.registerFactory<ClubImportCubit>(
    () => ClubImportCubit(
      graph<BackupFiles>(),
      PrepareClubImport(
        graph<BackupCodec>(),
        graph<BackupRules>(),
        store,
        scope,
        graph<Clock>(),
      ),
      ClubImportRunner(store, InMemoryImportDailyLedger(graph<Clock>())),
      ListImportTargets(
        graph<GroupRepository>(),
        graph<SeasonRepository>(),
        scope,
      ),
      scope,
      graph<ConnectivityStatus>(),
    ),
  );
}
