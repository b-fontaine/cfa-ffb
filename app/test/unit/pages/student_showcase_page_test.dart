import 'package:billard_cfa/features/student_showcase/presentation/bloc/showcase_cubit.dart';
import 'package:billard_cfa/pages/student_showcase/presentation/student_showcase_page.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/sheet_world.dart';
import '../shared/ui/pump_ui.dart';

/// Le bouton (Material) qui porte [text], icône comprise.
Finder buttonWith(String text) => find.ancestor(
  of: find.text(text),
  matching: find.bySubtype<ButtonStyleButton>(),
);

class _MockShowcase extends MockCubit<ShowcaseState> implements ShowcaseCubit;

void main() {
  late _MockShowcase cubit;
  var done = 0;
  const student = StudentId('s1');

  setUpAll(() => registerFallbackValue(student));

  setUp(() {
    cubit = _MockShowcase();
    done = 0;
    when(() => cubit.load(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, ShowcaseState state) async {
    whenListen(cubit, const Stream<ShowcaseState>.empty(), initialState: state);
    await pumpUi(
      tester,
      BlocProvider<ShowcaseCubit>.value(
        value: cubit,
        child: StudentShowcasePage(studentId: student, onDone: () => done++),
      ),
    );
  }

  testWidgets('shows a loader while loading', (tester) async {
    await pump(tester, const ShowcaseState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the first name and the path, and ends with Done', (
    tester,
  ) async {
    final world = SheetWorld();
    await world.start();
    final showcase = await world.showcase(tester);
    await pump(
      tester,
      ShowcaseState(status: ShowcaseStatus.ready, showcase: showcase),
    );

    expect(find.text('s1'), findsOneWidget);
    expect(find.text('Your current exercise'), findsOneWidget);
    final button = buttonWith('Done');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(done, 1);
  });

  testWidgets('the system back button ends the showcase', (tester) async {
    final world = SheetWorld();
    await world.start();
    final showcase = await world.showcase(tester);
    await pump(
      tester,
      ShowcaseState(status: ShowcaseStatus.ready, showcase: showcase),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(done, 1);
  });

  testWidgets('a failure proposes to retry', (tester) async {
    await pump(
      tester,
      const ShowcaseState(
        status: ShowcaseStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    );

    await tester.tap(find.text('Retry'));

    verify(() => cubit.load(student)).called(1);
  });
}
