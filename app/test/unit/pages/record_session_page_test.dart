import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/record_results/domain/session_overview.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/pages/record_session/presentation/record_session_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<RecordResultsEvent, RecordResultsState>
    implements RecordResultsBloc;

RecordResultsState _ready({String? mainBlockId, SheetOption? sheet}) =>
    RecordResultsState(
      status: RecordStatus.ready,
      overview: SessionOverview(
        session: SessionRecord(
          id: const SessionId('x1'),
          groupId: const GroupId('g1'),
          seasonId: const SeasonId('season'),
          date: day(12),
          audience: Audience.children,
          present: const {},
          mainBlockId: mainBlockId,
        ),
        groupName: 'Jeunes',
        students: const [],
        attempts: const [],
        catalogue: buildCatalogue(),
        maxPassesPerExercise: 2,
        passesRequired: 5,
        sheet: sheet,
      ),
      exercise: ref('a', 1),
    );

void main() {
  late _MockBloc bloc;

  setUp(() => bloc = _MockBloc());

  Future<void> pump(
    WidgetTester tester,
    RecordResultsState state, {
    VoidCallback? onBack,
    bool fromGuide = false,
  }) {
    whenListen(
      bloc,
      const Stream<RecordResultsState>.empty(),
      initialState: state,
    );
    return pumpUi(
      tester,
      BlocProvider<RecordResultsBloc>.value(
        value: bloc,
        child: RecordSessionPage(onBack: onBack ?? () {}, fromGuide: fromGuide),
      ),
    );
  }

  testWidgets('shows the loading state', (tester) async {
    await pump(tester, const RecordResultsState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the failure', (tester) async {
    await pump(
      tester,
      const RecordResultsState(
        status: RecordStatus.failure,
        failure: NotFound('session', 'x1'),
      ),
    );

    expect(find.text('Item not found.'), findsOneWidget);
  });

  testWidgets('titles the session with its date and group', (tester) async {
    await pump(tester, _ready());

    expect(find.text('Session of Mon, Oct 12'), findsOneWidget);
    expect(find.text('Jeunes'), findsOneWidget);
  });

  testWidgets('adds the main notion of the session to the subtitle', (
    tester,
  ) async {
    await pump(tester, _ready(mainBlockId: 'a'));

    expect(find.text('Jeunes · Main notion: Bloc a'), findsOneWidget);
  });

  testWidgets('names the catalogue session it notes over the block', (
    tester,
  ) async {
    await pump(
      tester,
      _ready(
        mainBlockId: 'a',
        sheet: SheetOption(
          id: SheetId('demi-bille-2'),
          technique: 'demi-bille',
          techniqueRank: 2,
          title: 'Quantité demi-bille',
          part: 2,
          partCount: 2,
        ),
      ),
    );

    expect(
      find.text('Jeunes · Catalogue session: Quantité demi-bille, session 2/2'),
      findsOneWidget,
    );
    expect(find.textContaining('Main notion'), findsNothing);
  });

  testWidgets('goes back to the guide when it came from it', (tester) async {
    var back = 0;
    await pump(tester, _ready(), fromGuide: true, onBack: () => back++);

    await tester.tap(find.text('Back to the guided session'));

    expect(back, 1);
  });
}
