import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/register_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/register_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Inscription sur invitation (bloc fourni par l'appelant) ; [onBack] ramène à
/// la connexion.
class RegisterPage extends StatelessWidget {
  const RegisterPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RegisterCubit>();
    return ScrollPage(
      title: l10n.registerTitle,
      onBack: onBack,
      backLabel: l10n.authBackToSignIn,
      maxWidth: 480,
      children: [
        BlocBuilder<RegisterCubit, AuthFormState>(
          builder: (context, state) => RegisterForm(
            state: state,
            onSubmit: (code, email, password) =>
                cubit.submit(code: code, email: email, password: password),
          ),
        ),
      ],
    );
  }
}
