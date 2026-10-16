import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_catalogue_view.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/group_journey_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Catalogue des séances (onglet « Catalogue » de la destination « Séances ») :
/// les techniques et leurs séances. Le sous-titre de l'en-tête dit la taille
/// du catalogue ; l'animateur peut choisir un groupe pour voir son parcours
/// (faites, recommandée ensuite, à venir). La suggestion par groupe a son
/// propre onglet : aucun bouton ici.
///
/// Les blocs [SheetCatalogueBloc] et [GroupJourneyCubit] sont fournis par
/// l'appelant. Ouvrir une séance transmet le groupe choisi pour que le retour
/// le restaure.
class SheetCataloguePage extends StatelessWidget {
  const SheetCataloguePage({required this.onOpenSheet, super.key});

  final void Function(SheetId id, GroupId? group) onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: BlocBuilder<SheetCatalogueBloc, SheetCatalogueState>(
            builder: (context, state) {
              final failure = state.failure;
              final visible = state.visible;
              return switch (state.status) {
                SheetCatalogueStatus.loading => const LoadingView(),
                SheetCatalogueStatus.failure => ErrorView(
                  message: failureMessage(l10n, failure!),
                  onRetry: () => context.read<SheetCatalogueBloc>().add(
                    const SheetCatalogueEvent.started(),
                  ),
                ),
                SheetCatalogueStatus.ready => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: l10n.catalogueTitle,
                        subtitle: l10n.catalogueSummary(
                          visible!.techniqueCount,
                          visible.sheetCount,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      BlocBuilder<GroupJourneyCubit, GroupJourneyState>(
                        builder: (context, journey) {
                          final ids = [
                            for (final group in visible.groups)
                              for (final sheet in group.sheets) sheet.id,
                          ];
                          return SheetCatalogueView(
                            catalogue: visible,
                            filter: state.reviewFilter,
                            onFilter: (filter) =>
                                context.read<SheetCatalogueBloc>().add(
                                  SheetCatalogueEvent.reviewFilterSelected(
                                    filter: filter,
                                  ),
                                ),
                            onOpenSheet: (id) =>
                                onOpenSheet(id, journey.groupId),
                            groups: journey.choices,
                            selectedGroup: journey.groupId,
                            onGroupSelected: (group) =>
                                context.read<GroupJourneyCubit>().select(group),
                            marks: journey.marksFor(ids),
                            noStudents: journey.journey?.noStudents ?? false,
                            journeyFailure: journey.failure,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}
