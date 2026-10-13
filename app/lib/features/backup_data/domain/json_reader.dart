import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Lecture typée et stricte de valeurs JSON : toute valeur de mauvais type
/// lève `backupInvalid`.
class JsonReader {
  const JsonReader();

  /// Longueur maximale d'une chaîne (prénom, nom, titre, identifiant,
  /// remarque) : un fichier ne peut pas faire exploser la mémoire.
  static const maxStringLength = 500;

  /// Nombre maximal d'éléments d'une liste de la sauvegarde.
  static const maxItems = 50000;

  static const _invalid = InvariantViolation(InvariantCode.backupInvalid);

  Map<String, Object?> object(Object? value) =>
      value is Map<String, Object?> ? value : throw _invalid;

  List<Object?> list(Object? value) =>
      value is List<Object?> && value.length <= maxItems
      ? value
      : throw _invalid;

  List<Map<String, Object?>> objects(Object? value) => [
    for (final item in list(value)) object(item),
  ];

  String string(Object? value) =>
      value is String && value.length <= maxStringLength
      ? value
      : throw _invalid;

  String? optionalString(Object? value) => value == null ? null : string(value);

  /// Identifiant de séance du catalogue ; un identifiant mal formé est
  /// refusé (`backupInvalid`), un identifiant inconnu du catalogue relève de
  /// `BackupRules`.
  SheetId? optionalSheetId(Object? value) {
    if (value == null) return null;
    return SheetId.tryParse(string(value)) ?? (throw _invalid);
  }

  int integer(Object? value) => value is int ? value : throw _invalid;

  DateTime dateTime(Object? value) =>
      DateTime.tryParse(string(value)) ?? (throw _invalid);

  Audience audience(Object? value) =>
      Audience.values.asNameMap()[string(value)] ?? (throw _invalid);
}
