import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_form_state.freezed.dart';

/// Avancement d'un formulaire d'authentification.
enum AuthFormStatus {
  /// Saisie en cours (ou retour après un échec).
  editing,

  /// Envoi en cours : les boutons sont désactivés.
  submitting,

  /// Fait (inscription ou demande de réinitialisation aboutie).
  done,

  /// Échec : [AuthFormState.failure] dit lequel.
  failed,
}

/// État commun des formulaires de connexion, d'inscription et de « mot de
/// passe oublié ».
@freezed
abstract class AuthFormState with _$AuthFormState {
  const factory AuthFormState({
    @Default(AuthFormStatus.editing) AuthFormStatus status,

    /// Cause de l'échec, quand [status] est `failed`.
    AuthFailureCode? failure,

    /// Un courriel de vérification vient d'être (re)parti.
    @Default(false) bool verificationSent,
  }) = _AuthFormState;
}
