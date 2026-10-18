import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

/// État de la session (ADR 0024, décision 31). Le routeur n'en lit que le type.
@freezed
sealed class AuthState with _$AuthState {
  const AuthState._();

  /// Démarrage : on ne sait pas encore (SDK en cours d'initialisation, session
  /// persistée en cours de lecture). L'écran de démarrage est affiché.
  const factory AuthState.unknown() = AuthUnknown;

  /// Personne n'est connecté (ou l'adresse n'est pas vérifiée).
  const factory AuthState.signedOut() = AuthSignedOut;

  /// Connecté (adresse vérifiée) mais sans club actif : `choices` est vide (le
  /// compte n'est dans aucun club) ou liste les clubs à choisir.
  ///
  /// `isAdmin` : le compte est administrateur (il atteint « Administration »
  /// même sans club). `pendingInvitation` : le code gardé à l'inscription
  /// (FB2) que l'écran « Rejoindre un club » propose de consommer (FB3).
  const factory AuthState.noClub({
    required Account account,
    required List<ClubMembership> choices,
    @Default(false) bool isAdmin,
    InvitationCode? pendingInvitation,
  }) = AuthNoClub;

  /// Connecté, avec un club actif et un rôle : l'application s'ouvre.
  /// `choices` : tous les clubs du compte (plusieurs : « Changer de club » est
  /// proposé).
  const factory AuthState.ready({
    required Account account,
    required ClubMembership club,
    required List<ClubMembership> choices,
    @Default(false) bool isAdmin,
  }) = AuthReady;

  /// Le service de comptes est injoignable (initialisation échouée, ou clubs
  /// illisibles sans club retenu sur l'appareil).
  const factory AuthState.indisponible() = AuthIndisponible;

  /// Le serveur refuse la lecture des clubs du compte connecté (règle de
  /// sécurité, index manquant) : écran « Accès refusé à vos clubs », avec
  /// déconnexion et **sans** « Réessayer » (cela ne corrigerait rien).
  const factory AuthState.accessDenied() = AuthAccessDenied;

  /// Plusieurs clubs : la bascule est proposée.
  bool get canSwitchClub => switch (this) {
    AuthReady(:final choices) => choices.length > 1,
    _ => false,
  };
}
