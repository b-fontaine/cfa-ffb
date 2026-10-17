import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/ui/invitation_row.dart';
import 'package:billard_cfa/shared/ui/role_labels.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le libellé d'un état d'invitation ; `null` : inconnu (service injoignable).
String invitationStatusLabel(AppLocalizations l10n, InvitationStatus? status) =>
    switch (status) {
      InvitationStatus.waiting => l10n.invitationStatusWaiting,
      InvitationStatus.used => l10n.invitationStatusUsed,
      InvitationStatus.expired => l10n.invitationStatusExpired,
      null => l10n.invitationStatusUnknown,
    };

/// Les invitations émises depuis cet appareil : code, rôle, état en toutes
/// lettres et « Révoquer » (48 dp) tant qu'elles peuvent encore servir. Une
/// note rappelle pourquoi seules celles de cet appareil figurent ici (le
/// serveur ne liste jamais les invitations).
class IssuedInvitationsCard extends StatelessWidget {
  const IssuedInvitationsCard({
    required this.title,
    required this.invitations,
    required this.onRevoke,
    super.key,
  });

  final String title;
  final List<IssuedInvitationStatus> invitations;
  final void Function(InvitationCode code) onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (invitations.isEmpty)
            Text(l10n.clubInvitationsEmpty)
          else
            for (final item in invitations)
              InvitationRow(
                code: item.entry.code.readable,
                subtitle: l10n.invitationRowSubtitle(
                  item.entry.role.label(l10n),
                  invitationStatusLabel(l10n, item.status),
                ),
                revokeLabel: l10n.invitationRevoke,
                onRevoke:
                    item.status == InvitationStatus.waiting ||
                        item.status == null
                    ? () => onRevoke(item.entry.code)
                    : null,
              ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.clubInvitationsNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
