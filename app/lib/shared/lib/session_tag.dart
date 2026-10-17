import 'dart:convert';

/// Étiquette de la note de jeu d'une séance (lot 10b, ADR 0023) : une liste
/// **fermée** de jugements pédagogiques sur la séance elle-même, jamais sur un
/// élève et jamais en texte libre (un texte libre peut nommer un enfant, une
/// santé, un comportement : décision de l'animateur du 2026-10-17).
///
/// L'ordre de déclaration est l'ordre d'affichage et d'écriture. Le code
/// enregistré est le [name] : ne jamais renommer une valeur sans migration.
/// La liste elle-même est une proposition `[Prop]`, non publiée par la FFB.
enum SessionTag {
  gameAppreciated,
  instructionsToRephrase,
  tooLong,
  tooShort,
  tooHard,
  tooEasy,
  toRedo,
  equipmentLacking;

  /// L'étiquette de code [code], `null` si ce code n'en est pas un.
  static SessionTag? tryParse(String code) =>
      SessionTag.values.asNameMap()[code];
}

/// Les codes de [tags], dans l'ordre d'affichage (écriture stable).
List<String> sessionTagCodes(Set<SessionTag> tags) => [
  for (final tag in SessionTag.values)
    if (tags.contains(tag)) tag.name,
];

/// Les codes de [tags] en liste JSON (voir [sessionTagCodes]).
String encodeSessionTags(Set<SessionTag> tags) =>
    jsonEncode(sessionTagCodes(tags));

/// Lit la liste JSON écrite par [encodeSessionTags].
///
/// Strict (par défaut) : un code inconnu, un doublon ou une forme inattendue
/// lève une [FormatException]. Tolérant ([strict] faux) : les codes inconnus
/// sont ignorés et un texte illisible donne l'ensemble vide (donnée durable
/// d'une saisie : elle ne doit pas bloquer l'ouverture de l'application).
Set<SessionTag> decodeSessionTags(String text, {bool strict = true}) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List<Object?>) {
      throw const FormatException('liste JSON attendue');
    }
    final tags = <SessionTag>{};
    for (final item in decoded) {
      final tag = item is String ? SessionTag.tryParse(item) : null;
      if (tag == null) {
        if (strict) throw const FormatException('étiquette inconnue');
        continue;
      }
      if (!tags.add(tag) && strict) {
        throw const FormatException('étiquette en double');
      }
    }
    return tags;
  } on FormatException {
    if (strict) rethrow;
    return const {};
  }
}
