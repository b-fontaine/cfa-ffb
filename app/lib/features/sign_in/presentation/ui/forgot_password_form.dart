import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/auth_fields.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Formulaire « Mot de passe oublié » : une adresse e-mail ; la même
/// confirmation que l'adresse ait un compte ou non.
class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({
    required this.state,
    required this.onSubmit,
    super.key,
  });

  final AuthFormState state;
  final void Function(String email) onSubmit;

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isSubmitting(widget.state)) widget.onSubmit(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.forgotPasswordIntro),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          onSubmitted: (_) => _submit(),
          decoration: authDecoration(l10n.authEmailLabel),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthFormFeedback(state: widget.state, success: l10n.forgotPasswordSent),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: isSubmitting(widget.state) ? null : _submit,
          child: Text(l10n.forgotPasswordSubmit),
        ),
      ],
    );
  }
}
