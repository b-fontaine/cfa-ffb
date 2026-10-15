import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/backup_view.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc;

void main() {
  Future<void> pumpView(WidgetTester tester, BackupState state) async {
    final bloc = _MockBackupBloc();
    whenListen(bloc, const Stream<BackupState>.empty(), initialState: state);
    await pumpUi(
      tester,
      BlocProvider<BackupBloc>.value(
        value: bloc,
        child: const SingleChildScrollView(
          child: BackupView(fileName: 'backup.json'),
        ),
      ),
    );
  }

  testWidgets('lists the reasons of a volatile storage separated by commas', (
    tester,
  ) async {
    await pumpView(
      tester,
      const BackupState(
        persistent: false,
        storageReasons: ['OPFS unavailable', 'no IndexedDB'],
      ),
    );

    expect(
      find.textContaining('Reason: OPFS unavailable, no IndexedDB'),
      findsOneWidget,
    );
  });

  testWidgets('announces a cancelled export only when it was cancelled', (
    tester,
  ) async {
    await pumpView(
      tester,
      const BackupState(status: BackupStatus.exportCancelled),
    );
    expect(find.text('Export cancelled.'), findsOneWidget);

    await pumpView(tester, const BackupState());
    expect(find.text('Export cancelled.'), findsNothing);
  });

  testWidgets('says when the previewed backup includes the settings', (
    tester,
  ) async {
    const summary = ImportSummary(
      seasons: 1,
      students: 1,
      groups: 1,
      sessionRecords: 0,
      attempts: 0,
      assessments: 0,
      plannedSessions: 0,
      blockAcquisitions: 0,
      settings: true,
    );
    await pumpView(
      tester,
      const BackupState(status: BackupStatus.previewing, preview: summary),
    );

    expect(find.text('Club settings included'), findsOneWidget);

    await pumpView(
      tester,
      BackupState(
        status: BackupStatus.previewing,
        preview: summary.copyWith(settings: false),
      ),
    );

    expect(find.text('Club settings included'), findsNothing);
  });
}
