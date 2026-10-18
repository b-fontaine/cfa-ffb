import 'package:billard_cfa/shared/lib/failure.dart';

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
      if (parsed != null) return parsed;
    }
    throw ServiceFailure(
      ServiceFailureCode.other,
      'malformed document $path: $field is not a date',
    );
  }

  /// Écriture d'une date : ISO 8601, qui garde le fuseau (UTC ou local) et les
  /// microsecondes ; les règles acceptent ce texte (`optStamp`, 40 caractères).
  static String encodeDate(DateTime date) => date.toIso8601String();
}
