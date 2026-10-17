import 'package:billard_cfa/features/administration/presentation/bloc/administration_cubit.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_state.dart';
import 'package:billard_cfa/features/administration/presentation/ui/administered_club_card.dart';
import 'package:billard_cfa/features/administration/presentation/ui/create_club_dialog.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/invitation_code_card.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// « Administration » (administrateur) : les clubs, « Créer un club » et, par
/// club, « Inviter un directeur ». Le code d'une invitation tout juste créée
/// s'affiche en tête, avec ses boutons de copie. Le cubit est fourni par
/// l'appelant ; [onBack] ramène d'où l'on vient.
class AdministrationPage extends StatelessWidget {
  const AdministrationPage({
    required this.onBack,
    this.backLabel,
    this.linkFor,
    super.key,
  });

  final VoidCallback onBack;

  /// Libellé du retour (par défaut « Retour »).
  final String? backLabel;
  final String Function(InvitationCode code)? linkFor;

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<AdministrationCubit>();
    final name = await showCreateClubDialog(context);
    if (name != null) await cubit.createClub(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdministrationCubit>();
    return ScrollPage(
      title: l10n.adminTitle,
      subtitle: l10n.adminIntro,
      onBack: onBack,
      backLabel: backLabel ?? l10n.adminBack,
      children: [
        BlocBuilder<AdministrationCubit, AdministrationState>(
          builder: (context, state) {
            final failure = state.failure;
            final issued = state.issued;
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
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.adminCreateClub),
                  ),
                ),
                const SizedBox(height: 16),
                if (issued != null) ...[
                  InvitationCodeCard(
                    code: issued.code,
                    validUntil: issued.expiresAt,
                    linkFor: linkFor,
                  ),
                  const SizedBox(height: 16),
                ],
                switch (state.status) {
                  AdministrationStatus.loading => const LoadingView(),
                  AdministrationStatus.failed => const SizedBox.shrink(),
                  AdministrationStatus.ready =>
                    state.clubs.isEmpty
                        ? EmptyState(message: l10n.adminClubsEmpty)
                        : Column(
                            children: [
                              for (final entry in state.clubs) ...[
                                AdministeredClubCard(
                                  entry: entry,
                                  onInviteDirector: () =>
                                      cubit.inviteDirector(entry.club.id),
                                  onRevoke: (code) =>
                                      cubit.revoke(entry.club.id, code),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                },
              ],
            );
          },
        ),
      ],
    );
  }
}
