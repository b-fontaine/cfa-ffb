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
class RecordSessionPage extends StatelessWidget {
  const RecordSessionPage({required this.onBack, super.key});

  final VoidCallback onBack;

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
            final blockId = overview.session.mainBlockId;
            final block = blockId == null
                ? null
                : overview.catalogue.blockById(blockId);
            return ScrollPage(
              title: l10n.recordSessionTitle(
                dates.formatMediumDate(overview.session.date),
              ),
              subtitle: block == null
                  ? overview.groupName
                  : '${overview.groupName} · '
                        '${l10n.recordBlockHint(block.title)}',
              onBack: onBack,
              backLabel: l10n.recordTitle,
              children: [RecordSessionView(state: state)],
            );
        }
      },
    );
  }
}
