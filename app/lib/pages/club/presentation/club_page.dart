import 'package:billard_cfa/features/manage_club/presentation/bloc/club_cubit.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/club_state.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/club_members_card.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/issued_invitations_card.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/rename_club_dialog.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// « Mon club » : inviter quelqu'un, les invitations de cet appareil et, pour
/// le directeur et l'administrateur, l'équipe, les familles et le nom du club.
/// Le cubit est fourni par l'appelant ; [onRenamed] relit la session (le nom
/// affiché vient d'elle).
class ClubPage extends StatelessWidget {
  const ClubPage({
    required this.clubName,
    required this.onInvite,
    required this.onBack,
    required this.onRenamed,
    super.key,
  });

  final String clubName;
  final VoidCallback onInvite;
  final VoidCallback onBack;
  final VoidCallback onRenamed;

  Future<void> _rename(BuildContext context) async {
    final cubit = context.read<ClubCubit>();
    final name = await showRenameClubDialog(context, clubName);
    if (name == null) return;
    if (await cubit.rename(name)) onRenamed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ClubCubit>();
    return ScrollPage(
      title: l10n.clubTitle,
      subtitle: clubName,
      onBack: onBack,
      backLabel: l10n.switchClubBackToMore,
      children: [
        BlocBuilder<ClubCubit, ClubState>(
          builder: (context, state) {
            final failure = state.failure;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (failure != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: AppAlert(
                      level: AlertLevel.persistent,
                      message: failureMessage(l10n, failure),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onInvite,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(l10n.clubInviteAction),
                    ),
                    if (state.canManage)
                      OutlinedButton.icon(
                        onPressed: () => _rename(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.clubRename),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (state.status == ClubStatus.loading)
                  const LoadingView()
                else ...[
                  if (state.canManage) ...[
                    ClubMembersCard(
                      members: state.members,
                      canRemove: state.removable,
                      onRemove: cubit.removeMember,
                    ),
                    const SizedBox(height: 16),
                  ],
                  IssuedInvitationsCard(
                    title: l10n.clubInvitationsTitle,
                    invitations: state.invitations,
                    onRevoke: cubit.revoke,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
