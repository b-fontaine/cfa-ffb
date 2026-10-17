import 'package:billard_cfa/entities/account/domain/auth_failure.dart';

/// Longueur minimale d'un mot de passe à l'inscription (ADR 0024, décision 24).
const int minPasswordLength = 10;

/// Longueur minimale d'un code d'invitation (ADR 0024, décision 24).
const int minInvitationCodeLength = 10;

final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Vrai si [email] a la forme d'une adresse (le fournisseur reste juge de son
/// existence : on ne vérifie ici que ce qui évite un aller-retour inutile).
bool isPlausibleEmail(String email) => _emailShape.hasMatch(email.trim());

/// Code d'invitation saisi : normalisé (majuscules, sans espaces ni tirets).
///
/// Seule la **forme** est contrôlée ici (au moins dix caractères de l'alphabet
/// Base32 : lettres et chiffres 2 à 7). Existence, expiration, rôle et club
/// relèvent du lot FB3, qui consomme le code côté serveur.
extension type const InvitationCode._(String value) {
  /// Le code normalisé, ou un `AuthFailure(invalidInvitationCode)`.
  factory InvitationCode.parse(String raw) {
    final value = raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (value.length < minInvitationCodeLength ||
        !RegExp(r'^[A-Z2-7]+$').hasMatch(value)) {
      throw const AuthFailure(AuthFailureCode.invalidInvitationCode);
    }
    return InvitationCode._(value);
  }
}
