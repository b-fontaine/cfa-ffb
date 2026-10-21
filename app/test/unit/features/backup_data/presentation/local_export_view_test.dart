import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/local_data_notice_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/local_export_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/local_data_banner.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/local_export_view.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_send_status.dart';
import '../../../shared/ui/pump_ui.dart';

class _MockExport extends Mock implements ExportLocalBackup;

class _FixedCubit extends LocalExportCubit {
  _FixedCubit(LocalExportState initial)
    : super(_MockExport(), InMemoryBackupFiles(), InMemoryLocalDataProbe()) {
    emit(initial);
  }
}

const _summary = ImportSummary(
  seasons: 1,
  students: 12,
  groups: 2,
  sessionRecords: 9,
  attempts: 240,
  assessments: 0,
  plannedSessions: 0,
  blockAcquisitions: 0,
);

void main() {
  Future<void> pumpView(
    WidgetTester tester,
    LocalExportState state, {
    Locale locale = const Locale('en'),
  }) async {
    final cubit = _FixedCubit(state);
    addTearDown(cubit.close);
    await pumpUi(
      tester,
      BlocProvider<LocalExportCubit>.value(
        value: cubit,
        child: const SingleChildScrollView(
          child: LocalExportView(fileName: 'x.json'),
        ),
      ),
      locale: locale,
    );
  }

  void narrowScreen(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  testWidgets('French counters say 0, not 1, when a count is zero', (
    tester,
  ) async {
    await pumpView(
      tester,
      const LocalExportState(
        status: LocalExportStatus.ready,
        summary: _summary,
      ),
      locale: const Locale('fr'),
    );

    // Sans cas `=0`, le français range 0 avec « un » (« 1 bilan »).
    expect(find.text('0 bilan'), findsOneWidget);
    expect(find.text('0 séance planifiée'), findsOneWidget);
    expect(find.text('0 bloc acquis'), findsOneWidget);
    expect(find.text('1 bilan'), findsNothing);
    expect(find.text('240 passages'), findsOneWidget);
  });

  for (final status in LocalExportStatus.values) {
    testWidgets('$status fits 320 dp wide at double text size', (tester) async {
      narrowScreen(tester);

      await pumpView(
        tester,
        LocalExportState(
          status: status,
          summary:
              status == LocalExportStatus.ready ||
                  status == LocalExportStatus.saved ||
                  status == LocalExportStatus.cancelled
              ? _summary
              : null,
          migrated: true,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the action to save has a 48 dp target', (tester) async {
    await pumpView(
      tester,
      const LocalExportState(
        status: LocalExportStatus.ready,
        summary: _summary,
      ),
    );

    final size = tester.getSize(find.byType(FilledButton));

    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the empty-file warning is announced as a live region', (
    tester,
  ) async {
    await pumpView(
      tester,
      const LocalExportState(
        status: LocalExportStatus.ready,
        summary: ImportSummary(
          seasons: 0,
          students: 0,
          groups: 0,
          sessionRecords: 0,
          attempts: 0,
          assessments: 0,
          plannedSessions: 0,
          blockAcquisitions: 0,
        ),
      ),
    );

    expect(
      find.ancestor(
        of: find.textContaining('This file is empty'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.liveRegion ?? false),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the banner fits 320 dp wide at double text size', (
    tester,
  ) async {
    narrowScreen(tester);

    await pumpUi(
      tester,
      SingleChildScrollView(
        child: LocalDataBanner(
          inventory: const LocalDataInventory(
            state: LocalStoreState.present,
            counts: LocalDataCounts(students: 12, attempts: 240),
          ),
          onExport: () {},
          onAcknowledge: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Export now'), findsOneWidget);
    expect(find.text('I have imported my data into the club'), findsOneWidget);
  });

  testWidgets('an unreadable base offers to read again, not to confirm', (
    tester,
  ) async {
    var reread = 0;
    await pumpUi(
      tester,
      LocalDataBanner(
        inventory: const LocalDataInventory(state: LocalStoreState.unreadable),
        onExport: () => reread++,
        onAcknowledge: () {},
      ),
    );

    expect(find.text('I have imported my data into the club'), findsNothing);
    await tester.tap(find.text('Read the data again'));
    expect(reread, 1);
  });

  testWidgets('the frame keeps the screen in place when the banner goes', (
    tester,
  ) async {
    final probe = InMemoryLocalDataProbe()
      ..inventory = const LocalDataInventory(
        state: LocalStoreState.present,
        counts: LocalDataCounts(students: 1),
      );
    final cubit = LocalDataNoticeCubit(
      probe,
      InMemoryKeyValueStore(),
      FakeSendStatus(),
    );
    addTearDown(cubit.close);
    await cubit.load(account: 'u-anne');
    final key = GlobalKey();
    await pumpUi(
      tester,
      LocalDataNoticeFrame(
        cubit: cubit,
        onExport: () {},
        onAcknowledge: cubit.acknowledge,
        child: SizedBox(key: key),
      ),
    );
    final element = tester.element(find.byKey(key));
    expect(find.text('Export now'), findsOneWidget);

    await cubit.acknowledge();
    await tester.pump();

    expect(find.text('Export now'), findsNothing);
    expect(tester.element(find.byKey(key)), same(element));
  });
}
