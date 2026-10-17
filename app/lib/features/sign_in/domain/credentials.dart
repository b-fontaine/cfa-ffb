import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';

export 'package:billard_cfa/shared/lib/invitation_code.dart'
    show InvitationCode, minInvitationCodeLength;

/// Longueur minimale d'un mot de passe à l'inscription (ADR 0024, décision 24).
const int minPasswordLength = 10;

final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Vrai si [email] a la forme d'une adresse (le fournisseur reste juge de son
/// existence : on ne vérifie ici que ce qui évite un aller-retour inutile).
bool isPlausibleEmail(String email) => _emailShape.hasMatch(email.trim());

/// Le code d'invitation saisi, normalisé (majuscules, sans espaces ni tirets),
/// ou un `AuthFailure(invalidInvitationCode)` si sa **forme** n'est pas celle
/// d'un code (au moins dix caractères Base32 : lettres et chiffres 2 à 7).
/// Existence, expiration, rôle et club sont jugés par le serveur (FB3).
InvitationCode parseInvitationCode(String raw) =>
    InvitationCode.tryParse(raw) ??
    (throw const AuthFailure(AuthFailureCode.invalidInvitationCode));
