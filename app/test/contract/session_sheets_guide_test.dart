import 'package:billard_cfa/entities/exercise_catalog/data/asset_catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/data/asset_diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/in_memory_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session_sheet/data/asset_session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/features/run_sheet/domain/load_validated_exercises.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_presentation_view.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Contrat de rendu de la séance guidée et de la présentation sur les 28
// vraies séances de `assets/fiches/` : pour chaque séance, chaque public et
// chaque étape, aucune erreur de rendu (débordement compris), en français et
// en anglais, texte à 200 % sur téléphone et tablette en paysage.

const _locales = [Locale('fr'), Locale('en')];

/// (nom, taille logique, facteur de texte).
const _screens = [
  ('téléphone, texte à 200 %', Size(360, 800), 2.0),
  ('tablette en paysage', Size(1024, 768), 1.0),
];

Widget _app(Locale locale, double textScale, Widget body) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SafeArea(
      child: Padding(padding: const EdgeInsets.all(16), child: body),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SessionSheet> sheets;
  late ResolveRunPlan resolve;

  setUpAll(() async {
    final repository = AssetSessionSheetRepository.fromBundle();
    sheets = await repository.getAll();
    resolve = ResolveRunPlan(
      repository,
      InMemorySessionRepository(),
      AssetCatalogueRepository.fromBundle(),
      AssetDiagramRepository.fromBundle(),
      RulesStore(RulesConfig()),
      LoadValidatedExercises(
        InMemoryStudentRepository(),
        InMemoryGroupRepository(),
        InMemoryAttemptRepository(),
        InMemoryAcquisitionRepository(),
        RulesStore(RulesConfig()),
      ),
    );
  });

  Future<RunPlan> planOf(SessionSheet sheet, Audience audience) async =>
      switch (await resolve(sheet.id, audience: audience)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('${sheet.id} : $failure'),
      };

  test(
    'every session has a plan whose minutes add up for both audiences',
    () async {
      for (final sheet in sheets) {
        for (final audience in Audience.values) {
          final plan = await planOf(sheet, audience);

          expect(
            plan.steps.fold(0, (sum, s) => sum + s.minutes),
            audience.sessionDuration.inMinutes,
            reason: '${sheet.id} ${audience.name}',
          );
          expect(plan.steps.first.kind, RunStepKind.recall);
          expect(plan.steps.last.kind, RunStepKind.review);
          expect(plan.diagramsUnreadable, isFalse, reason: '${sheet.id}');
        }
      }
    },
  );

  test('the results recall block is the nearest earlier other block', () async {
    final ordered = [...sheets]..sort((a, b) => a.order.compareTo(b.order));
    for (final sheet in ordered) {
      final plan = await planOf(sheet, Audience.children);
      final earlier = ordered
          .where(
            (s) =>
                s.order < sheet.order &&
                s.catalogueBlock != sheet.catalogueBlock,
          )
          .toList();

      expect(
        plan.recallBlockId,
        earlier.isEmpty ? isNull : earlier.last.catalogueBlock,
        reason: '${sheet.id}',
      );
    }
  });

  test('every exercise of a session has a diagram to show', () async {
    for (final sheet in sheets) {
      final plan = await planOf(sheet, Audience.adults);
      for (final step in plan.steps.where(
        (s) => s.kind == RunStepKind.exercise,
      )) {
        expect(plan.isPresentable(step), isTrue, reason: '${sheet.id}');
      }
    }
  });

  for (final locale in _locales) {
    for (final (screenName, size, scale) in _screens) {
      for (final audience in Audience.values) {
        testWidgets(
          'the guide and the presentation render in ${locale.languageCode}, '
          '$screenName, ${audience.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            for (final sheet in sheets) {
              final plan = (await tester.runAsync(
                () => planOf(sheet, audience),
              ))!;
              final cubit = RunSheetCubit(
                resolve,
                PeriodicRunTicker(),
                RunKey(sheetId: sheet.id, audience: audience),
              );
              await tester.runAsync(cubit.load);
              addTearDown(cubit.close);

              for (final index in List.generate(plan.stepCount, (i) => i)) {
                cubit.showStep(index);
                await tester.pumpWidget(
                  _app(
                    locale,
                    scale,
                    BlocProvider.value(
                      value: cubit,
                      child: BlocBuilder<RunSheetCubit, RunSheetState>(
                        builder: (context, state) => RunSheetView(
                          state: state,
                          onStep: (_) {},
                          onShow: () {},
                          onFinish: () {},
                          onRecord: (_) {},
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pump();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'guide ${sheet.id} étape $index',
                );

                await tester.pumpWidget(
                  _app(
                    locale,
                    scale,
                    RunPresentationView(
                      plan: plan,
                      step: index,
                      onPrevious: () {},
                      onNext: () {},
                      onClose: () {},
                    ),
                  ),
                );
                await tester.pump();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'présentation ${sheet.id} étape $index',
                );
              }
            }
          },
        );
      }
    }
  }
}
