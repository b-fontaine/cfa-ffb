import 'dart:async';

import 'package:billard_cfa/features/export_sheet/presentation/bloc/export_sheet_cubit.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/export_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Export PDF d'une séance du catalogue (ADR 0021) : feuille de l'animateur ou
/// fiches résultats, aperçu, enregistrement et impression. Le cubit est fourni
/// par l'appelant, qui le démarre avec la source du document.
///
/// L'écran est de premier niveau (hors du cadre de navigation) : [onBack]
/// revient à la séance ou au guide d'où l'on vient, [onHome] est proposé quand
/// la séance n'existe pas.
class ExportSheetPage extends StatelessWidget {
  const ExportSheetPage({
    required this.onBack,
    required this.onHome,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<ExportSheetCubit, ExportSheetState>(
      builder: (context, state) {
        final cubit = context.read<ExportSheetCubit>();
        return switch (state.status) {
          ExportStatus.loading => const Scaffold(body: LoadingView()),
          ExportStatus.notFound => MissingPageView(onHome: onHome),
          ExportStatus.failure => Scaffold(
            body: ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: () => unawaited(cubit.retried()),
              onBack: onBack,
            ),
          ),
          ExportStatus.ready => ScrollPage(
            title: l10n.exportTitle,
            onBack: onBack,
            backLabel: l10n.exportBackLabel,
            children: [
              ExportView(
                state: state,
                onKindChanged: (kind) => unawaited(cubit.kindChanged(kind)),
                onAudienceChanged: (audience) =>
                    unawaited(cubit.audienceChanged(audience)),
                onGroupChanged: (id) => unawaited(cubit.groupChosen(id)),
                onNamesChanged: (value) =>
                    unawaited(cubit.namesToggled(value: value)),
                onPageChanged: cubit.pageChanged,
                onSave: () => unawaited(cubit.save()),
                onPrint: () => unawaited(cubit.print()),
              ),
            ],
          ),
        };
      },
    );
  }
}
