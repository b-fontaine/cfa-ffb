import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_catalogue_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Catalogue des séances (destination « Séances » du menu) : les techniques
/// et leurs séances, en lecture seule. [onOpenSuggestion] mène à la
/// suggestion par groupe, qui reste accessible en tête de page.
class SheetCataloguePage extends StatelessWidget {
  const SheetCataloguePage({
    required this.onOpenSheet,
    required this.onOpenSuggestion,
    super.key,
  });

  final ValueChanged<SheetId> onOpenSheet;
  final VoidCallback onOpenSuggestion;

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
                      PageHeader(title: l10n.catalogueTitle),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: onOpenSuggestion,
                          icon: const Icon(Icons.event_note_outlined),
                          label: Text(l10n.catalogueSuggestion),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SheetCatalogueView(
                        catalogue: visible!,
                        filter: state.reviewFilter,
                        onFilter: (filter) =>
                            context.read<SheetCatalogueBloc>().add(
                              SheetCatalogueEvent.reviewFilterSelected(
                                filter: filter,
                              ),
                            ),
                        onOpenSheet: onOpenSheet,
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
