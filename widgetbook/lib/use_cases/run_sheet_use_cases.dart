import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_presentation_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_presentation_view.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_sheet_view.dart';
import 'package:billard_cfa/pages/sheet_guide/presentation/sheet_guide_page.dart';
import 'package:billard_cfa/pages/sheet_presentation/presentation/sheet_presentation_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

// Séance guidée (ADR 0004, lot L6) : la vue d'étape, la présentation aux
// élèves et leurs pages, sur les 28 vraies séances de l'application.

const _features = '[Features]';
const _pages = '[Pages]';

/// Séances proposées au choix : une première séance, une partie 2, une séance
/// à jeu adapté `[Prop]` et une séance d'un bloc `[Prop]`.
const _sheetIds = [
  'demi-bille-1',
  'demi-bille-2',
  'posture-1',
  'bille-fantome-1',
  'retro-4',
];

SheetId _chosenSheet(BuildContext context) => SheetId(
  context.knobs.object.dropdown<String>(
    label: 'séance',
    options: _sheetIds,
    initialOption: _sheetIds.first,
  ),
);

Audience _chosenAudience(BuildContext context) =>
    context.knobs.object.dropdown<Audience>(
      label: 'public',
      options: Audience.values,
      initialOption: Audience.children,
      labelBuilder: (audience) => audience.name,
    );

/// Étape affichée : les curseurs bornent la valeur au déroulé chargé.
int _chosenStep(BuildContext context, RunPlan plan) => context.knobs.int.slider(
  label: 'étape (à partir de 0)',
  max: plan.stepCount - 1,
);

@widgetbook.UseCase(name: 'Séance guidée', type: RunSheetView, path: _features)
Widget buildRunSheetViewUseCase(BuildContext context) {
  final id = _chosenSheet(context);
  final audience = _chosenAudience(context);
  final key = RunKey(sheetId: id, audience: audience);
  return WorldScope(
    builder: (context, world) {
      final cubit = getIt<RunSheetSessions>().of(key);
      return LoadedScope<RunPlan>(
        key: ValueKey(key),
        load: (_) async {
          await cubit.load();
          final plan = cubit.state.plan;
          return plan == null ? throw StateError('séance illisible') : Ok(plan);
        },
        builder: (context, world, plan) {
          cubit.showStep(_chosenStep(context, plan));
          return BlocProvider.value(
            value: cubit,
            child: BlocBuilder<RunSheetCubit, RunSheetState>(
              builder: (context, state) => Padding(
                padding: const EdgeInsets.all(16),
                child: RunSheetView(
                  state: state,
                  onStep: cubit.showStep,
                  onShow: () {},
                  onFinish: () {},
                  onRecord: (_) {},
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

@widgetbook.UseCase(
  name: 'Présentation aux élèves',
  type: RunPresentationView,
  path: _features,
)
Widget buildRunPresentationViewUseCase(BuildContext context) {
  final id = _chosenSheet(context);
  final audience = _chosenAudience(context);
  return WorldScope(
    builder: (context, world) => LoadedScope<RunPlan>(
      key: ValueKey((id, audience)),
      load: (_) => getIt<ResolveRunPlan>()(id, audience: audience),
      builder: (context, world, plan) => Padding(
        padding: const EdgeInsets.all(16),
        child: RunPresentationView(
          plan: plan,
          step: _chosenStep(context, plan),
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Séance guidée', type: SheetGuidePage, path: _pages)
Widget buildSheetGuidePageUseCase(BuildContext context) {
  final id = _chosenSheet(context);
  final audience = _chosenAudience(context);
  final key = RunKey(sheetId: id, audience: audience);
  return WorldScope(
    builder: (context, world) {
      final cubit = getIt<RunSheetSessions>().of(key);
      unawaited(cubit.load());
      return BlocProvider.value(
        key: ValueKey(key),
        value: cubit,
        child: SheetGuidePage(
          onBack: () {},
          onHome: () {},
          onShow: (_) {},
          onRecord: (_, _, _) {},
          onFinish: () {},
          onStepChanged: (_) {},
        ),
      );
    },
  );
}

@widgetbook.UseCase(
  name: 'Présentation',
  type: SheetPresentationPage,
  path: _pages,
)
Widget buildSheetPresentationPageUseCase(BuildContext context) {
  final id = _chosenSheet(context);
  final audience = _chosenAudience(context);
  return WorldScope(
    builder: (context, world) => BlocProvider(
      key: ValueKey((id, audience)),
      create: (_) {
        final cubit = getIt<RunPresentationCubit>();
        unawaited(cubit.started(sheetId: id, audience: audience, step: 1));
        return cubit;
      },
      child: SheetPresentationPage(onClose: (_) {}, onHome: () {}),
    ),
  );
}
