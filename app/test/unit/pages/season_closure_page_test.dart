import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/pages/season_closure/presentation/season_closure_page.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';
import '../shared/ui/pump_ui.dart';

class _MockClosure extends MockBloc<SeasonClosureEvent, SeasonClosureState>
    implements SeasonClosureBloc;

class _MockBackup extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc;

void main() {
  late _MockClosure closure;
  late _MockBackup backup;
  var cancelled = 0;

  setUpAll(() => registerFallbackValue(const BackupEvent.started()));

  final ready = SeasonClosureState(
    status: SeasonClosureStatus.ready,
    plan: ClosurePlan(
      season: Season(
        id: const SeasonId('s'),
        label: '2026-2027',
        startDate: day(1),
        endDate: day(31),
      ),
      closedOn: day(12),
      early: false,
      audiences: const [],
      proposals: const [],
      plannedToDrop: 0,
    ),
  );

  setUp(() {
    closure = _MockClosure();
    backup = _MockBackup();
    cancelled = 0;
    when(() => closure.state).thenReturn(ready);
    whenListen(
      closure,
      const Stream<SeasonClosureState>.empty(),
      initialState: ready,
    );
    when(() => backup.add(any())).thenReturn(null);
  });

  Future<void> pump(WidgetTester tester, BackupState state) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(backup, const Stream<BackupState>.empty(), initialState: state);
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<SeasonClosureBloc>.value(value: closure),
          BlocProvider<BackupBloc>.value(value: backup),
        ],
        child: SeasonClosurePage(
          today: DateTime(2026, 10, 12),
          onCancel: () => cancelled++,
          onSeasons: () {},
          onHome: () {},
        ),
      ),
    );
  }

  testWidgets('names the season and leaves by its back button', (tester) async {
    await pump(tester, const BackupState());

    expect(find.text('Close the 2026-2027 season'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));

    expect(cancelled, 1);
  });

  testWidgets('the export button asks for a dated backup file', (tester) async {
    await pump(tester, const BackupState());

    await tester.tap(find.text('Export a backup'));

    verify(
      () => backup.add(
        const BackupEvent.exportRequested(
          fileName: 'billiards-backup-2026-10-12.json',
        ),
      ),
    ).called(1);
  });

  testWidgets('says when the backup is done', (tester) async {
    await pump(tester, const BackupState(status: BackupStatus.exported));

    expect(find.text('Backup done.'), findsOneWidget);
  });

  testWidgets('says when the export was cancelled', (tester) async {
    await pump(tester, const BackupState(status: BackupStatus.exportCancelled));

    expect(find.text('Export cancelled.'), findsOneWidget);
    expect(find.text('Backup done.'), findsNothing);
  });

  testWidgets('shows a failed export', (tester) async {
    await pump(
      tester,
      const BackupState(
        status: BackupStatus.failure,
        failure: NotFound('x', 'y'),
      ),
    );

    expect(find.text('Item not found.'), findsOneWidget);
  });

  testWidgets('blocks a second export while one is running', (tester) async {
    await pump(tester, const BackupState(status: BackupStatus.working));

    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Export a backup'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
