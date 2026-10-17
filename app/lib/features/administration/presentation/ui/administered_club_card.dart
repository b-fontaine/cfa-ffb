import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_state.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/ui/invitation_row.dart';
import 'package:billard_cfa/shared/ui/role_labels.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Un club de l'administration : son nom, « Inviter un directeur » (48 dp) et
/// les invitations de directeur envoyées depuis cet appareil, révocables tant
/// qu'elles peuvent servir.
class AdministeredClubCard extends StatelessWidget {
  const AdministeredClubCard({
    required this.entry,
    required this.onInviteDirector,
    required this.onRevoke,
    super.key,
  });

  final AdministeredClub entry;
  final VoidCallback onInviteDirector;
  final void Function(InvitationCode code) onRevoke;

  static String _status(AppLocalizations l10n, InvitationStatus? status) =>
      switch (status) {
        InvitationStatus.waiting => l10n.invitationStatusWaiting,
        InvitationStatus.used => l10n.invitationStatusUsed,
        InvitationStatus.expired => l10n.invitationStatusExpired,
        null => l10n.invitationStatusUnknown,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: entry.club.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: onInviteDirector,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.adminInviteDirector),
            ),
          ),
          if (entry.invitations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.adminDirectorInvitationsNote,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final item in entry.invitations)
              InvitationRow(
                code: item.entry.code.readable,
                subtitle: l10n.invitationRowSubtitle(
                  item.entry.role.label(l10n),
                  _status(l10n, item.status),
                ),
                revokeLabel: l10n.invitationRevoke,
                onRevoke:
                    item.status == InvitationStatus.waiting ||
                        item.status == null
                    ? () => onRevoke(item.entry.code)
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}
