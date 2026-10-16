import 'dart:async';

import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_presentation_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_presentation_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Largeur maximale (dp) du contenu de la présentation.
const double _maxWidth = 1200;

/// Présentation plein écran d'une séance du catalogue : l'illustration de
/// l'étape, agrandie, pour les élèves (cubit fourni par l'appelant).
///
/// Route de premier niveau, hors du cadre de navigation : [onClose] reçoit
/// l'étape affichée pour revenir à la séance guidée à cette étape. Le plein
/// écran vient d'un `FullscreenCubit` fourni par l'appelant ; fermer la
/// présentation ne le quitte pas.
class SheetPresentationPage extends StatelessWidget {
  const SheetPresentationPage({
    required this.onClose,
    required this.onHome,
    super.key,
  });

  final ValueChanged<int> onClose;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<RunPresentationCubit, RunPresentationState>(
      builder: (context, state) {
        final cubit = context.read<RunPresentationCubit>();
        return switch (state.status) {
          PresentationStatus.loading => const Scaffold(body: LoadingView()),
          PresentationStatus.notFound => MissingPageView(onHome: onHome),
          PresentationStatus.failure => Scaffold(
            body: ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: () => unawaited(cubit.retry()),
              onBack: () => onClose(state.step),
            ),
          ),
          PresentationStatus.ready => Scaffold(
            key: const ValueKey('presentation'),
            body: SafeArea(
              // Marges verticales réduites : en paysage sur téléphone, chaque
              // dp compte pour le schéma.
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: RunPresentationView(
                      plan: state.plan!,
                      step: state.step,
                      onPrevious: cubit.previous,
                      onNext: cubit.next,
                      onClose: () => onClose(state.step),
                      fullscreen: context.watch<FullscreenCubit>().state,
                      onToggleFullscreen: () =>
                          unawaited(context.read<FullscreenCubit>().toggle()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}
