import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/auth_fields.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Formulaire d'inscription sur invitation : code, adresse e-mail et mot de
/// passe d'au moins dix caractères. Il ne crée que le compte d'authentification
/// (le rattachement au club est le lot FB3).
class RegisterForm extends StatefulWidget {
  const RegisterForm({required this.state, required this.onSubmit, super.key});

  final AuthFormState state;
  final void Function(String code, String email, String password) onSubmit;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isSubmitting(widget.state)) {
      widget.onSubmit(_code.text, _email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final done = widget.state.status == AuthFormStatus.done;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.registerIntro(minPasswordLength)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: authDecoration(l10n.registerCodeLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            autocorrect: false,
            decoration: authDecoration(l10n.authEmailLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            decoration: authDecoration(
              l10n.authPasswordLabel,
              hint: l10n.registerPasswordHint(minPasswordLength),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AuthFormFeedback(
            state: widget.state,
            success: widget.state.verificationSent
                ? l10n.registerDone
                : l10n.registerDoneNoMail,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: isSubmitting(widget.state) || done ? null : _submit,
            child: Text(l10n.registerSubmit),
          ),
        ],
      ),
    );
  }
}
