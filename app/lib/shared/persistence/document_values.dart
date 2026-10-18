import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';

/// Lecture tolérante des champs d'un document : une valeur du mauvais type est
/// une [ServiceFailure] (`other`) qui nomme le champ, jamais une exception
/// du langage ni une valeur devinée.
final class DocumentValues {
  const DocumentValues(this.path, this.fields);

  /// Chemin du document (diagnostic seulement : pas d'identité d'élève dans un
  /// message d'erreur affiché, et ces messages ne sont pas affichés).
  final String path;
  final Map<String, Object?> fields;

  Never _bad(String field, String expected) => throw ServiceFailure(
    ServiceFailureCode.other,
    'malformed document $path: $field is not $expected',
  );

  String string(String field) {
    final value = fields[field];
    return value is String ? value : _bad(field, 'a string');
  }

  String? optString(String field) {
    final value = fields[field];
    if (value == null) return null;
    return value is String ? value : _bad(field, 'a string');
  }

  int integer(String field, {required int fallback}) {
    final value = fields[field];
    if (value == null) return fallback;
    return value is int ? value : _bad(field, 'an integer');
  }

  List<Object?> list(String field) {
    final value = fields[field];
    if (value == null) return const [];
    return value is List<Object?> ? value : _bad(field, 'a list');
  }

  DateTime? optDate(String field) => decodeDate(fields[field], path, field);

  DateTime date(String field) =>
      optDate(field) ?? _bad(field, 'a date (missing)');

  /// Une date écrite par l'application (texte ISO 8601, fuseau conservé) ou par
  /// le serveur (`DateTime` issu d'un horodatage).
  static DateTime? decodeDate(Object? value, String path, String field) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null && _keepsCalendar(value)) return parsed;
    }
    throw ServiceFailure(
      ServiceFailureCode.other,
      'malformed document $path: $field is not a date',
    );
  }

  /// `DateTime.tryParse` CORRIGE une date fausse (30 février -> 2 mars) : on
  /// contrôle donc les composantes du texte (jour du mois, heure, minute,
  /// seconde), sans repasser par un `DateTime` local, dont la relecture
  /// dépendrait du fuseau de l'appareil (heure inexistante au changement
  /// d'heure).
  static bool _keepsCalendar(String text) {
    final match = _calendar.firstMatch(text);
    if (match == null) return true;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > DateTime.utc(year, month + 1, 0).day) return false;
    if (match.group(4) == null) return true;
    return int.parse(match.group(4)!) <= 23 &&
        int.parse(match.group(5)!) <= 59 &&
        int.parse(match.group(6)!) <= 59;
  }

  static final RegExp _calendar = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}):(\d{2}))?',
  );

  /// Écriture d'une date : ISO 8601, qui garde le fuseau (UTC ou local) et les
  /// microsecondes ; les règles n'acceptent que ce texte (`isoText` : plages du
  /// calendrier comprises, 40 caractères au plus).
  static String encodeDate(DateTime date) => date.toIso8601String();
}

/// Décode [documents] en **écartant** ceux qui sont malformés (une
/// [ServiceFailure] `other` du décodeur) : un seul document mal formé (créé
/// avant les règles, ou par un autre client) ne doit pas rendre illisible toute
/// la liste d'un élève, d'un groupe ou d'un club. Les autres échecs remontent.
List<T> decodeValid<T>(
  Iterable<StoredDocument> documents,
  T Function(StoredDocument document) decode,
) {
  final decoded = <T>[];
  for (final document in documents) {
    try {
      decoded.add(decode(document));
    } on ServiceFailure catch (failure) {
      if (failure.code != ServiceFailureCode.other) rethrow;
    }
  }
  return decoded;
}
