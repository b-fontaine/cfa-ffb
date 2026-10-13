import 'dart:async';

import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/sheet_option.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Liste des séances planifiées avec public, durée et séance du catalogue.
///
/// Une séance liée propose d'ouvrir son détail ([onOpenSheet], avec le public
/// de la séance planifiée) ; une séance libre, ou liée à une séance que le
/// catalogue ne connaît plus (« indisponible », jamais une erreur), propose
/// d'en choisir une ([onChooseSheet]). Une séance liée peut aussi être lancée
/// en séance guidée ([onLaunchSheet], avec le public et l'identifiant de la
/// séance planifiée). [onDelete], quand il est donné, ajoute à chaque ligne
/// une suppression après confirmation : une erreur de public ou de lien se
/// corrige en supprimant puis en replanifiant.
class SessionList extends StatelessWidget {
  const SessionList({
    required this.sessions,
    required this.sheetOptions,
    required this.onOpenSheet,
    required this.onChooseSheet,
    required this.onLaunchSheet,
    this.onDelete,
    super.key,
  });

  final List<Session> sessions;

  /// Séances du catalogue connues : sert à libeller le lien.
  final List<SheetOption> sheetOptions;
  final void Function(SheetId id, Audience audience) onOpenSheet;
  final VoidCallback onChooseSheet;
  final void Function(SheetId id, Audience audience, String sessionId)
  onLaunchSheet;
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
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final audience = switch (session.audience) {
          Audience.children => l10n.audienceChildren,
          Audience.adults => l10n.audienceAdults,
        };
        final minutes = l10n.sessionDurationMinutes(session.duration.inMinutes);
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
              Text('$audience · $minutes'),
              if (sheetId != null && option == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(l10n.plannerSheetUnavailable),
                ),
              if (option != null)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
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
                      onPressed: () => onLaunchSheet(
                        option.id,
                        session.audience,
                        session.id,
                      ),
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text(l10n.guideLaunch),
                    ),
                  ],
                )
              else
                TextButton(
                  onPressed: onChooseSheet,
                  child: Text(l10n.plannerChooseSheet),
                ),
            ],
          ),
        );
      },
    );
  }
}
