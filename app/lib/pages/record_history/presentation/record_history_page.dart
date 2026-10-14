import 'package:billard_cfa/features/record_results/presentation/bloc/recorded_sessions_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/recorded_session_list.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Historique des séances saisies (onglet Résultats) : liste et ouverture
/// d'une séance, ou d'une nouvelle saisie (bloc fourni par le routeur).
class RecordHistoryPage extends StatelessWidget {
  const RecordHistoryPage({
    required this.onOpenSession,
    required this.onNewSession,
    super.key,
  });

  final ValueChanged<SessionId> onOpenSession;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: BlocBuilder<RecordedSessionsBloc, RecordedSessionsState>(
            builder: (context, state) {
              final failure = state.failure;
              return switch (state.status) {
                RecordedSessionsStatus.loading => const LoadingView(),
                RecordedSessionsStatus.failure => ErrorView(
                  message: failureMessage(l10n, failure!),
                  onRetry: () => context.read<RecordedSessionsBloc>().add(
                    const RecordedSessionsEvent.refreshed(),
                  ),
                ),
                RecordedSessionsStatus.ready => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: l10n.historyTitle,
                        subtitle: l10n.historySubtitle,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.icon(
                          onPressed: onNewSession,
                          icon: const Icon(Icons.add),
                          label: Text(l10n.historyNew),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RecordedSessionList(
                        sessions: state.sessions,
                        onOpenSession: onOpenSession,
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
