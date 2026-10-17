import 'dart:math';

/// Longueur minimale d'un code d'invitation (ADR 0024, décision 24).
const int minInvitationCodeLength = 10;

/// Longueur maximale d'un code d'invitation (bornée aussi par les règles
/// Firestore : `[A-Z2-7]{10,32}`).
const int maxInvitationCodeLength = 32;

/// Longueur des codes que l'application génère : douze caractères de
/// l'alphabet Base32, soit 60 bits, de quoi résister à l'énumération (aucune
/// limitation de débit sans Cloud Functions, ADR 0024 « Limites assumées »).
const int generatedInvitationCodeLength = 12;

/// Alphabet Base32 (RFC 4648) : les lettres et les chiffres 2 à 7. Aucun 0, 1,
/// 8 ni 9 : « O » ne se confond pas avec zéro, « I » et « L » pas avec un.
const String invitationAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

final RegExp _separators = RegExp(r'[\s-]');
final RegExp _alphabetOnly = RegExp(r'^[A-Z2-7]+$');

/// Code d'invitation : au moins [minInvitationCodeLength] caractères Base32
/// sans caractère ambigu, normalisé en majuscules. Seule la **forme** est
/// contrôlée ici ; existence, expiration, rôle et club sont jugés côté serveur.
extension type const InvitationCode._(String value) {
  /// Un code tiré au hasard ; [random] doit être cryptographique en
  /// production (`Random.secure()`).
  factory InvitationCode.generate(Random random) => InvitationCode._(
    String.fromCharCodes([
      for (var i = 0; i < generatedInvitationCodeLength; i++)
        invitationAlphabet.codeUnitAt(
          random.nextInt(invitationAlphabet.length),
        ),
    ]),
  );

  /// Le code normalisé (majuscules, sans espace ni tiret), ou `null` si la
  /// forme n'est pas celle d'un code.
  static InvitationCode? tryParse(String raw) {
    final value = raw.toUpperCase().replaceAll(_separators, '');
    if (value.length < minInvitationCodeLength ||
        value.length > maxInvitationCodeLength ||
        !_alphabetOnly.hasMatch(value)) {
      return null;
    }
    return InvitationCode._(value);
  }

  /// Le code coupé par groupes de quatre pour la lecture (`ABCD-EFGH-JKMN`).
  String get readable => [
    for (var i = 0; i < value.length; i += 4)
      value.substring(i, min(i + 4, value.length)),
  ].join('-');
}
