import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/forgot_password_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/forgot_password_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// « Mot de passe oublié » (bloc fourni par l'appelant) ; [onBack] ramène à la
/// connexion.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ForgotPasswordCubit>();
    return ScrollPage(
      title: l10n.forgotPasswordTitle,
      onBack: onBack,
      backLabel: l10n.authBackToSignIn,
      maxWidth: 480,
      children: [
        BlocBuilder<ForgotPasswordCubit, AuthFormState>(
          builder: (context, state) => ForgotPasswordForm(
            state: state,
            onSubmit: (email) => cubit.submit(email: email),
          ),
        ),
      ],
    );
  }
}
