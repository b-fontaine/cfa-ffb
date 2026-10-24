import 'package:billard_cfa/features/delete_account/presentation/bloc/delete_account_cubit.dart';
import 'package:billard_cfa/features/delete_account/presentation/bloc/delete_account_state.dart';
import 'package:billard_cfa/features/delete_account/presentation/ui/delete_account_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// « Supprimer mon compte » (FB8 partie B, B2), ouvert depuis « Plus » ou
/// l'écran « Aucun club » (cubit fourni par l'appelant). Un administrateur
/// ([isAdministrator]) n'a pas de formulaire : son compte se supprime en
/// console, la page l'explique.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({
    required this.onBack,
    this.isAdministrator = false,
    super.key,
  });

  final VoidCallback onBack;
  final bool isAdministrator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: l10n.deleteAccountTitle,
      onBack: onBack,
      backLabel: l10n.commonBack,
      maxWidth: 480,
      children: [
        if (isAdministrator)
          AppAlert(
            level: AlertLevel.attention,
            message: l10n.deleteAccountAdministrator,
          )
        else
          BlocBuilder<DeleteAccountCubit, DeleteAccountState>(
            builder: (context, state) => DeleteAccountForm(
              state: state,
              onSubmit: context.read<DeleteAccountCubit>().submit,
            ),
          ),
      ],
    );
  }
}
