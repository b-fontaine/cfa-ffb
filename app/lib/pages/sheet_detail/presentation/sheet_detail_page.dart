import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_detail_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Une séance du catalogue en lecture seule (bloc fourni par l'appelant).
/// [onBack] revient au catalogue ; [onHome] est proposé quand la séance
/// n'existe pas ; [onPlan] ouvre le planificateur sur cette séance ;
/// [onLaunch] lance la séance guidée pour le public affiché. [fromPlanner]
/// dit que la séance est ouverte depuis le planificateur : [onBack] y revient
/// et le libellé du retour le dit.
class SheetDetailPage extends StatelessWidget {
  const SheetDetailPage({
    required this.onBack,
    required this.onHome,
    required this.onPlan,
    required this.onLaunch,
    this.fromPlanner = false,
    super.key,
  });

  final VoidCallback onBack;
  final bool fromPlanner;
  final VoidCallback onHome;

  /// Planifie cette séance du catalogue, pour le public affiché.
  final ValueChanged<Audience> onPlan;

  /// Lance la séance guidée, pour le public affiché.
  final ValueChanged<Audience> onLaunch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SheetDetailBloc, SheetDetailState>(
      builder: (context, state) {
        final detail = state.detail;
        return switch (state.status) {
          SheetDetailStatus.loading => const Scaffold(body: LoadingView()),
          SheetDetailStatus.notFound => MissingPageView(onHome: onHome),
          SheetDetailStatus.failure => Scaffold(
            body: ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: () => context.read<SheetDetailBloc>().add(
                const SheetDetailEvent.retried(),
              ),
              onBack: onBack,
            ),
          ),
          SheetDetailStatus.ready => ScrollPage(
            title: l10n.sheetFullTitle(
              detail!.sheet.title,
              detail.sheet.part,
              detail.partCount,
            ),
            onBack: onBack,
            backLabel: fromPlanner ? l10n.plannerTitle : l10n.catalogueTitle,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => onLaunch(state.audience),
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: Text(l10n.guideLaunch),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onPlan(state.audience),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(l10n.sheetPlan),
                  ),
                ],
              ),
              SheetDetailView(
                detail: detail,
                audience: state.audience,
                onAudienceChanged: (audience) => context
                    .read<SheetDetailBloc>()
                    .add(SheetDetailEvent.audienceChanged(audience: audience)),
              ),
            ],
          ),
        };
      },
    );
  }
}
