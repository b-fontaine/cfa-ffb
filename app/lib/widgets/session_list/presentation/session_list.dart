import 'dart:async';

import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Liste des séances planifiées : date, groupe, public, durée et séance du
/// catalogue.
///
/// Une séance liée propose d'ouvrir son détail ([onOpenSheet], avec le public
/// de la séance planifiée) ; une séance libre, ou liée à une séance que le
/// catalogue ne connaît plus (« indisponible », jamais une erreur), propose
/// d'en choisir une ([onChooseSheet]). Une séance liée peut aussi être lancée
/// en séance guidée ([onLaunchSheet], avec le public et l'identifiant de la
/// séance planifiée). Une séance planifiée pour un groupe propose de **noter
/// ses résultats** ([onRecord], avec la séance du catalogue si elle est
/// connue) tant qu'aucune saisie n'existe pour ce groupe ce jour-là, puis
/// d'**ouvrir** cette saisie ([onOpenRecord]) (ADR 0007). [onDelete], quand
/// il est donné, ajoute à chaque ligne une suppression après confirmation.
class SessionList extends StatelessWidget {
  const SessionList({
    required this.sessions,
    required this.sheetOptions,
    required this.onOpenSheet,
    required this.onChooseSheet,
    required this.onLaunchSheet,
    required this.onRecord,
    required this.onOpenRecord,
    this.onDelete,
    super.key,
  });

  final List<PlannedSessionSummary> sessions;

  /// Séances du catalogue connues : sert à libeller le lien.
  final List<SheetOption> sheetOptions;
  final void Function(SheetId id, Audience audience) onOpenSheet;
  final VoidCallback onChooseSheet;
  final void Function(SheetId id, Audience audience, String sessionId)
  onLaunchSheet;
  final void Function(GroupId group, DateTime date, SheetId? sheet) onRecord;
  final ValueChanged<SessionId> onOpenRecord;
  final ValueChanged<Session>? onDelete;

  Future<void> _confirmDelete(BuildContext context, Session session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.plannerDeleteTitle,
      message: l10n.plannerDeleteBody(session.title),
    );
    if (confirmed) onDelete?.call(session);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (sessions.isEmpty) {
      return EmptyState(message: l10n.plannerEmpty);
    }
    final known = {for (final option in sheetOptions) option.id: option};
    // Une colonne (pas une liste défilante) : la page qui la compose défile
    // en entier, formulaire compris.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final summary in sessions) _row(context, l10n, known, summary),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    Map<SheetId, SheetOption> known,
    PlannedSessionSummary summary,
  ) {
    final session = summary.session;
    final sheetId = session.sheetId;
    final option = sheetId == null ? null : known[sheetId];
    return ListTile(
      trailing: onDelete == null
          ? null
          : IconButton(
              tooltip: l10n.plannerDelete(session.title),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => unawaited(_confirmDelete(context, session)),
            ),
      title: Text(session.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_line(context, summary)),
          if (summary.groupUnavailable)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l10n.plannerGroupUnavailable),
            ),
          if (sheetId != null && option == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l10n.plannerSheetUnavailable),
            ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (option != null) ...[
                TextButton(
                  onPressed: () => onOpenSheet(option.id, session.audience),
                  child: Text(
                    l10n.plannerLinkedSheet(
                      l10n.sheetFullTitle(
                        option.title,
                        option.part,
                        option.partCount,
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      onLaunchSheet(option.id, session.audience, session.id),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(l10n.guideLaunch),
                ),
              ] else
                TextButton(
                  onPressed: onChooseSheet,
                  child: Text(l10n.plannerChooseSheet),
                ),
              ..._recordActions(l10n, summary, option),
            ],
          ),
        ],
      ),
    );
  }

  /// « lun. 12 oct. · Jeunes · Enfants · 90 min » (le groupe quand il est
  /// connu).
  String _line(BuildContext context, PlannedSessionSummary summary) {
    final l10n = AppLocalizations.of(context);
    final session = summary.session;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(session.date);
    final audience = session.audience.label(l10n);
    final minutes = session.duration.inMinutes;
    final group = summary.group;
    return group == null
        ? l10n.plannerSessionLine(date, audience, minutes)
        : l10n.plannerSessionGroupLine(date, group.name, audience, minutes);
  }

  /// Noter les résultats (groupe connu, rien de saisi) ou ouvrir la saisie.
  List<Widget> _recordActions(
    AppLocalizations l10n,
    PlannedSessionSummary summary,
    SheetOption? option,
  ) {
    final group = summary.group;
    if (group == null) return const [];
    final recordId = summary.recordId;
    if (recordId != null) {
      return [
        TextButton.icon(
          onPressed: () => onOpenRecord(recordId),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(l10n.plannerRecorded),
        ),
      ];
    }
    return [
      TextButton.icon(
        onPressed: () => onRecord(group.id, summary.session.date, option?.id),
        icon: const Icon(Icons.edit_note),
        label: Text(l10n.plannerRecord),
      ),
    ];
  }
}
