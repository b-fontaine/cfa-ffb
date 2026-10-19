import 'package:billard_cfa/features/sign_in/presentation/ui/erasure_pending_notice.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/shared_device_note.dart';
import 'package:billard_cfa/features/sync_status/domain/sync_state.dart';
import 'package:billard_cfa/features/sync_status/presentation/ui/sync_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Compte]';

@widgetbook.UseCase(
  name: 'Pastille de synchronisation',
  type: SyncStatusChip,
  path: _path,
)
Widget buildSyncStatusChipUseCase(BuildContext context) {
  final phase = context.knobs.object.dropdown<SyncPhase>(
    label: 'État',
    options: SyncPhase.values,
    labelBuilder: (value) => value.name,
  );
  final pending = context.knobs.int.slider(
    label: 'Envois en attente',
    initialValue: 2,
  );
  final offline = context.knobs.boolean(label: 'Hors ligne');
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SyncStatusChip(
        state: SyncState(
          phase: phase,
          pending: phase == SyncPhase.pending ? pending : 0,
          offline: offline || phase == SyncPhase.offline,
        ),
        onAcknowledgeFailure: () {},
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Avertissement appareil partagé',
  type: SharedDeviceNote,
  path: _path,
)
Widget buildSharedDeviceNoteUseCase(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: SharedDeviceNote());

@widgetbook.UseCase(
  name: 'Effacement hors ligne à réessayer',
  type: ErasurePendingNotice,
  path: _path,
)
Widget buildErasurePendingNoticeUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: ErasurePendingNotice(onRetry: () {}),
);
