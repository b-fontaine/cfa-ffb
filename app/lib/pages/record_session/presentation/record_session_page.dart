import 'package:billard_cfa/features/record_results/domain/session_overview.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/record_session_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Saisie des résultats d'une séance ouverte (bloc fourni par l'appelant).
///
/// [fromGuide] : la saisie a été ouverte depuis une séance guidée ; le retour
/// y ramène et le dit.
class RecordSessionPage extends StatelessWidget {
  const RecordSessionPage({
    required this.onBack,
    this.fromGuide = false,
    super.key,
  });

  final VoidCallback onBack;
  final bool fromGuide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    return BlocBuilder<RecordResultsBloc, RecordResultsState>(
      builder: (context, state) {
        final failure = state.failure;
        switch (state.status) {
          case RecordStatus.loading:
            return const Scaffold(body: LoadingView());
          case RecordStatus.failure:
            return Scaffold(
              body: ErrorView(message: failureMessage(l10n, failure!)),
            );
          case RecordStatus.ready:
            final overview = state.overview!;
            final hint = _hint(l10n, overview);
            return ScrollPage(
              title: l10n.recordSessionTitle(
                dates.formatMediumDate(overview.session.date),
              ),
              subtitle: hint == null
                  ? overview.groupName
                  : l10n.recordSessionSubtitle(overview.groupName, hint),
              onBack: onBack,
              backLabel: fromGuide ? l10n.guideBackToGuide : l10n.recordTitle,
              children: [RecordSessionView(state: state)],
            );
        }
      },
    );
  }

  /// La séance du catalogue notée quand elle est connue (ADR 0007), sinon la
  /// notion principale, sinon rien.
  String? _hint(AppLocalizations l10n, SessionOverview overview) {
    final sheet = overview.sheet;
    if (sheet != null) {
      return l10n.recordSheetHint(
        l10n.sheetFullTitle(sheet.title, sheet.part, sheet.partCount),
      );
    }
    final blockId = overview.session.mainBlockId;
    final block = blockId == null
        ? null
        : overview.catalogue.blockById(blockId);
    if (block == null) return null;
    final hint = l10n.recordBlockHint(block.title);
    return block.isProposal ? l10n.proposalTagged(hint) : hint;
  }
}
