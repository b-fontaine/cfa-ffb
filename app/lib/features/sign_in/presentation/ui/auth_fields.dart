import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/auth_failure_message.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:flutter/material.dart';

/// Décoration commune des champs des formulaires d’authentification.
InputDecoration authDecoration(String label, {String? hint}) =>
    InputDecoration(labelText: label, hintText: hint);

/// Zone d'erreur d'un formulaire : annoncée aux lecteurs d'écran à son
/// apparition (région vive), jamais par la couleur seule ([AppAlert] porte
/// icône et libellé).
class AuthFormFeedback extends StatelessWidget {
  const AuthFormFeedback({required this.state, this.success, super.key});

  final AuthFormState state;

  /// Message de réussite, affiché quand le formulaire est « fait ».
  final String? success;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = state.failure;
    final String? message;
    if (state.status == AuthFormStatus.failed && failure != null) {
      message = authFailureMessage(l10n, failure);
    } else {
      message = null;
    }
    if (message != null) {
      return Semantics(
        liveRegion: true,
        child: AppAlert(level: AlertLevel.persistent, message: message),
      );
    }
    final ok = success;
    if (state.status == AuthFormStatus.done && ok != null) {
      return Semantics(liveRegion: true, child: Text(ok));
    }
    if (state.status == AuthFormStatus.submitting) {
      return Semantics(liveRegion: true, child: Text(l10n.authSubmitting));
    }
    return const SizedBox.shrink();
  }
}

/// Vrai si [state] attend une réponse : les boutons sont alors désactivés.
bool isSubmitting(AuthFormState state) =>
    state.status == AuthFormStatus.submitting;

/// L'échec est « adresse non vérifiée » (le renvoi du courriel est proposé).
bool needsVerification(AuthFormState state) =>
    state.status == AuthFormStatus.failed &&
    state.failure == AuthFailureCode.emailNotVerified;
