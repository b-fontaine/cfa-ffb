import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/role_labels.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// L'équipe et les familles du club : le nom affiché et le rôle de chaque
/// membre, et « Retirer l'accès » (48 dp, confirmation) pour ceux que
/// [canRemove] autorise. Retirer un membre ne supprime pas son compte.
class ClubMembersCard extends StatelessWidget {
  const ClubMembersCard({
    required this.members,
    required this.canRemove,
    required this.onRemove,
    super.key,
  });

  final List<Member> members;
  final bool Function(Member member) canRemove;
  final void Function(Member member) onRemove;

  Future<void> _confirmRemove(BuildContext context, Member member) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.clubMemberRemoveTitle(member.displayName),
      message: l10n.clubMemberRemoveBody,
      confirmLabel: l10n.clubMemberRemoveConfirm,
    );
    if (confirmed) onRemove(member);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.clubMembersTitle,
      child: members.isEmpty
          ? Text(l10n.clubMembersEmpty)
          : Column(
              children: [
                for (final member in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(member.displayName),
                    subtitle: Text(member.role.label(l10n)),
                    trailing: canRemove(member)
                        ? TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppSpacing.minTouchTarget,
                              ),
                            ),
                            onPressed: () => _confirmRemove(context, member),
                            child: Text(l10n.clubMemberRemove),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
