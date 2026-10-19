import 'dart:async';

import 'package:billard_cfa/features/student_showcase/domain/check_family_access.dart';
import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/watch_family_space.dart';
import 'package:billard_cfa/features/student_showcase/presentation/bloc/family_space_cubit.dart';
import 'package:billard_cfa/pages/my_children/presentation/my_children_page.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Get extends Mock implements GetFamilySpace;

class _Watch extends Mock implements WatchFamilySpace;

class _Access extends Mock implements CheckFamilyAccess;

FamilyChild _child(String id, String name) => FamilyChild(
  id: StudentId(id),
  firstName: name,
  showcase: StudentShowcase(
    firstName: name,
    rows: const [],
    current: null,
    validatedCount: 0,
    finishedTechniques: 0,
    techniqueCount: 0,
    toStart: true,
    passesRequired: 5,
  ),
);

void main() {
  late _Get get;
  late _Access access;
  late FamilySpaceCubit cubit;

  setUp(() {
    get = _Get();
    access = _Access();
    final watch = _Watch();
    when(watch.call).thenAnswer((_) => const Stream<void>.empty());
    when(() => access())
        .thenAnswer((_) async => const AccessGranted({StudentId('s1')}));
    cubit = FamilySpaceCubit(get, watch, access);
    addTearDown(cubit.close);
  });

  Future<void> pump(
    WidgetTester tester, {
    bool student = false,
    bool load = true,
  }) async {
    if (load) unawaited(cubit.load());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: MyChildrenPage(studentOwnAccount: student),
        ),
      ),
    );
    await tester.pump();
    // Annuler l'abonnement d'un flux (accès retiré) rend la main à la boucle
    // d'événements réelle : on la laisse tourner.
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
  }

  void answer(Result<FamilySpace> result) =>
      when(() => get(linked: any(named: 'linked')))
          .thenAnswer((_) async => result);

  testWidgets('a parent sees the title and the first child', (tester) async {
    answer(
      Ok(
        FamilySpace(
          children: [_child('s1', 'Léa'), _child('s2', 'Tom')],
          upcoming: const [],
        ),
      ),
    );
    await pump(tester);

    expect(find.text('My children'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Tom'), findsOneWidget);
    expect(find.text('Next sessions'), findsOneWidget);
  });

  testWidgets('a student sees "My progress"', (tester) async {
    answer(
      Ok(FamilySpace(children: [_child('s1', 'Léa')], upcoming: const [])),
    );
    await pump(tester, student: true);

    expect(find.text('My progress'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
  });

  testWidgets('shows a wait while loading', (tester) async {
    final never = Completer<Result<FamilySpace>>();
    when(() => get(linked: any(named: 'linked')))
        .thenAnswer((_) => never.future);
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an unreachable service gets an error and a retry', (
    tester,
  ) async {
    answer(const Err(ServiceFailure(ServiceFailureCode.unavailable)));
    await pump(tester);

    expect(
      find.text(
        'The service is not responding. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    answer(
      Ok(FamilySpace(children: [_child('s1', 'Léa')], upcoming: const [])),
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Léa'), findsOneWidget);
  });

  testWidgets('a refusal says "Access denied", not the unreachable service', (
    tester,
  ) async {
    answer(const Err(ServiceFailure(ServiceFailureCode.denied)));
    await pump(tester);

    expect(find.text('Access denied'), findsOneWidget);
    expect(find.textContaining('Sign out, then sign in again'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('not responding'), findsNothing);
  });

  testWidgets('a removed link says "Access removed" and shows no data', (
    tester,
  ) async {
    when(() => access()).thenAnswer((_) async => const AccessRevoked());
    answer(const Err(ServiceFailure(ServiceFailureCode.denied)));
    await pump(tester);

    expect(find.text('Access removed'), findsOneWidget);
    expect(find.textContaining('“More”'), findsOneWidget);
    expect(find.text('Léa'), findsNothing);
  });

  testWidgets('French: the family reads sober sentences', (tester) async {
    answer(const Err(ServiceFailure(ServiceFailureCode.denied)));
    when(() => access()).thenAnswer((_) async => const AccessRevoked());
    unawaited(cubit.load());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const MyChildrenPage(studentOwnAccount: false),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(find.text('Accès retiré'), findsOneWidget);
    expect(find.textContaining('« Plus »'), findsOneWidget);
  });
}
