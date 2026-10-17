import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/auth_fields.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Formulaire de connexion : adresse e-mail, mot de passe, liens vers
/// « Mot de passe oublié » et l'inscription par code. Sans état métier : la
/// page lui donne [state] et reçoit les actions.
class SignInForm extends StatefulWidget {
  const SignInForm({
    required this.state,
    required this.onSubmit,
    required this.onResendVerification,
    required this.onForgotPassword,
    required this.onRegister,
    super.key,
  });

  final AuthFormState state;
  final void Function(String email, String password) onSubmit;
  final void Function(String email, String password) onResendVerification;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isSubmitting(widget.state)) {
      widget.onSubmit(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = isSubmitting(widget.state);
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: authDecoration(l10n.authEmailLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: authDecoration(l10n.authPasswordLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          AuthFormFeedback(state: widget.state),
          if (widget.state.verificationSent) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(l10n.signInVerificationSent),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: Text(l10n.signInSubmit),
          ),
          if (needsVerification(widget.state)) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => widget.onResendVerification(
                      _email.text,
                      _password.text,
                    ),
              child: Text(l10n.signInResend),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: busy ? null : widget.onForgotPassword,
            child: Text(l10n.signInForgot),
          ),
          TextButton(
            onPressed: busy ? null : widget.onRegister,
            child: Text(l10n.signInRegister),
          ),
        ],
      ),
    );
  }
}
