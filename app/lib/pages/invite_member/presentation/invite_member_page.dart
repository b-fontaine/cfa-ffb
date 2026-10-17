import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_cubit.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_state.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/invite_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/invitation_code_card.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// « Inviter quelqu'un » : le formulaire, puis le code à remettre une fois
/// l'invitation créée. Le cubit est fourni par l'appelant ; [linkFor] est
/// la construction du lien web (sinon seul le code se copie).
class InviteMemberPage extends StatelessWidget {
  const InviteMemberPage({required this.onBack, this.linkFor, super.key});

  final VoidCallback onBack;
  final String Function(InvitationCode code)? linkFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<InviteCubit>();
    return ScrollPage(
      title: l10n.inviteTitle,
      onBack: onBack,
      backLabel: l10n.clubBack,
      maxWidth: 560,
      children: [
        BlocBuilder<InviteCubit, InviteState>(
          builder: (context, state) {
            final issued = state.issued;
            if (issued != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvitationCodeCard(
                    code: issued.code,
                    validUntil: issued.expiresAt,
                    linkFor: linkFor,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: cubit.another,
                    child: Text(l10n.inviteAnother),
                  ),
                ],
              );
            }
            return switch (state.load) {
              InviteLoad.loading => const LoadingView(),
              InviteLoad.failed => ErrorView(
                message: failureMessage(l10n, state.failure!),
                onRetry: cubit.load,
              ),
              InviteLoad.ready => InviteForm(
                state: state,
                onRole: cubit.selectRole,
                onGroup: cubit.toggleGroup,
                onStudent: cubit.toggleStudent,
                onAge: (value) => cubit.setAgeConfirmed(value: value),
                onSubmit: cubit.submit,
              ),
            };
          },
        ),
      ],
    );
  }
}
