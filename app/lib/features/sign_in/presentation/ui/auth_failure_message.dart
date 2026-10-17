import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';

/// Message localisé d'un échec d'authentification : générique, il ne dit jamais
/// si une adresse a un compte (ADR 0024, décision 31).
String authFailureMessage(AppLocalizations l10n, AuthFailureCode code) =>
    switch (code) {
      AuthFailureCode.invalidCredentials => l10n.authErrorInvalidCredentials,
      AuthFailureCode.emailNotVerified => l10n.authErrorEmailNotVerified,
      AuthFailureCode.invalidEmail => l10n.authErrorInvalidEmail,
      AuthFailureCode.weakPassword => l10n.authErrorWeakPassword(
        minPasswordLength,
      ),
      AuthFailureCode.invalidInvitationCode => l10n.authErrorInvalidCode(
        minInvitationCodeLength,
      ),
      AuthFailureCode.registrationFailed => l10n.authErrorRegistrationFailed,
      AuthFailureCode.tooManyRequests => l10n.authErrorTooManyRequests,
      AuthFailureCode.network => l10n.authErrorNetwork,
      AuthFailureCode.unavailable => l10n.authErrorUnavailable,
    };
