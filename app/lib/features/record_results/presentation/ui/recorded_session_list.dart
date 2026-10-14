import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Historique des séances saisies : une ligne par séance (date, groupe,
/// public, notion principale, présents, passages), chacune ouvrant la saisie.
class RecordedSessionList extends StatelessWidget {
  const RecordedSessionList({
    required this.sessions,
    required this.onOpenSession,
    super.key,
  });

  final List<RecordedSessionSummary> sessions;
  final ValueChanged<SessionId> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (sessions.isEmpty) {
      return EmptyState(message: l10n.historyEmpty, icon: Icons.history);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final summary in sessions) ...[
          _SessionRow(summary: summary, onOpenSession: onOpenSession),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.summary, required this.onOpenSession});

  final RecordedSessionSummary summary;
  final ValueChanged<SessionId> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final session = summary.session;
    final date = dates.formatMediumDate(session.date);
    final audience = session.audience.label(l10n);
    final sheet = summary.sheet;
    final block = summary.mainBlock;
    // La séance du catalogue notée prime sur la notion principale (ADR 0007).
    final blockHint = sheet != null
        ? l10n.recordSheetHint(
            l10n.sheetFullTitle(sheet.title, sheet.part, sheet.partCount),
          )
        : block == null
        ? null
        : block.isProposal
        ? l10n.proposalTagged(l10n.recordBlockHint(block.title))
        : l10n.recordBlockHint(block.title);
    return Semantics(
      button: true,
      label: l10n.historyOpen(date, summary.groupName),
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => onOpenSession(session.id),
          borderRadius: AppRadii.smallRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget + AppSpacing.md,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.recordSessionTitle(date),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.historyGroupLine(summary.groupName, audience),
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (blockHint != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(blockHint, style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final count in [
                              l10n.historyPresent(summary.presentCount),
                              l10n.historyPasses(summary.attemptCount),
                            ])
                              Text(
                                count,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
