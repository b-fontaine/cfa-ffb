import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/local_data_notice_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/local_export_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/local_data_banner.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/local_export_view.dart';
import 'package:billard_cfa/pages/local_export/presentation/local_export_page.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/lib/send_status.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _path = '[Export des données locales]';

const _full = ImportSummary(
  seasons: 2,
  students: 12,
  groups: 3,
  sessionRecords: 18,
  attempts: 240,
  assessments: 4,
  plannedSessions: 2,
  blockAcquisitions: 5,
);

const _nothing = ImportSummary(
  seasons: 1,
  students: 0,
  groups: 0,
  sessionRecords: 0,
  attempts: 0,
  assessments: 0,
  plannedSessions: 0,
  blockAcquisitions: 0,
);

/// Le cubit d'export posé dans l'état choisi par le bouton de maquette.
class _PreviewLocalExportCubit extends LocalExportCubit {
  _PreviewLocalExportCubit(LocalExportState initial)
    : super(
        getIt<ExportLocalBackup>(),
        getIt<BackupFiles>(),
        getIt<LocalDataProbe>(),
      ) {
    emit(initial);
  }
}

LocalExportState _state(BuildContext context) => switch (context.knobs.object
    .dropdown<String>(
      label: 'état',
      options: const [
        'fichier prêt',
        'fichier vide',
        'enregistré',
        'enregistrement annulé',
        'base plus récente',
        'illisible',
        'échec d’enregistrement',
        'lecture en cours',
        'base mise à niveau',
      ],
    )) {
  'fichier vide' => const LocalExportState(
    status: LocalExportStatus.ready,
    summary: _nothing,
  ),
  'enregistré' => const LocalExportState(
    status: LocalExportStatus.saved,
    summary: _full,
  ),
  'enregistrement annulé' => const LocalExportState(
    status: LocalExportStatus.cancelled,
    summary: _full,
  ),
  'base plus récente' => const LocalExportState(
    status: LocalExportStatus.newerSchema,
  ),
  'illisible' => const LocalExportState(status: LocalExportStatus.unreadable),
  'échec d’enregistrement' => const LocalExportState(
    status: LocalExportStatus.saveFailed,
  ),
  'lecture en cours' => const LocalExportState(),
  'base mise à niveau' => const LocalExportState(
    status: LocalExportStatus.ready,
    summary: _full,
    migrated: true,
  ),
  _ => const LocalExportState(status: LocalExportStatus.ready, summary: _full),
};

@widgetbook.UseCase(name: 'Export local', type: LocalExportView, path: _path)
Widget buildLocalExportViewUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider<LocalExportCubit>(
    create: (_) => _PreviewLocalExportCubit(_state(context)),
    child: const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: LocalExportView(fileName: 'donnees-locales-2026-10-21.json'),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Exporter mes données locales',
  type: LocalExportPage,
  path: _path,
)
Widget buildLocalExportPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider<LocalExportCubit>(
    create: (_) => _PreviewLocalExportCubit(_state(context)),
    child: LocalExportPage(today: world.today, onBack: () {}),
  ),
);

LocalDataInventory _inventory(BuildContext context) => switch (context
    .knobs
    .object
    .dropdown<String>(
      label: 'relevé',
      options: const ['données lues', 'base plus récente', 'illisible'],
    )) {
  'base plus récente' => const LocalDataInventory(
    state: LocalStoreState.newerSchema,
    schemaVersion: 13,
  ),
  'illisible' => const LocalDataInventory(state: LocalStoreState.unreadable),
  _ => const LocalDataInventory(
    state: LocalStoreState.present,
    schemaVersion: 12,
    counts: LocalDataCounts(students: 12, attempts: 240),
  ),
};

@widgetbook.UseCase(name: 'Bandeau', type: LocalDataBanner, path: _path)
Widget buildLocalDataBannerUseCase(BuildContext context) => LocalDataBanner(
  inventory: _inventory(context),
  onExport: () {},
  onAcknowledge:
      context.knobs.boolean(
        label: 'Connecté (action « J’ai importé »)',
        initialValue: true,
      )
      ? () {}
      : null,
);

@widgetbook.UseCase(
  name: 'Bandeau au-dessus d’un écran',
  type: LocalDataNoticeFrame,
  path: _path,
)
Widget buildLocalDataNoticeFrameUseCase(BuildContext context) {
  final probe = InMemoryLocalDataProbe()..inventory = _inventory(context);
  // Le bandeau a besoin de son relevé : lu à la création de la maquette.
  final cubit = LocalDataNoticeCubit(
    probe,
    InMemoryKeyValueStore(),
    _NothingToSend(),
  );
  unawaited(cubit.load(account: 'maquette'));
  return LocalDataNoticeFrame(
    cubit: cubit,
    onExport: () {},
    onAcknowledge: cubit.acknowledge,
    child: const Center(child: Text('Écran de l’application')),
  );
}

/// Maquette : aucun envoi en attente, le repère peut être posé.
class _NothingToSend implements SendStatus {
  @override
  int get pending => 0;

  @override
  Future<bool> hasUnsentWrites() async => false;

  @override
  Future<void> refresh() async {}

  @override
  Stream<int> get pendingChanges => const Stream.empty();

  @override
  bool get hasFailure => false;

  @override
  void clearFailure() {}
}
