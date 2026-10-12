import 'package:drift/drift.dart';

/// Stocke un `DateTime` en texte ISO 8601 : la valeur relue est identique à
/// l'originale (microsecondes, local ou UTC), contrairement au stockage par
/// défaut en secondes. Une date locale (minuit) reste « le même jour » même si
/// le fuseau de l'appareil change.
class IsoDateTimeConverter extends TypeConverter<DateTime, String> {
  const IsoDateTimeConverter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb);

  @override
  String toSql(DateTime value) => value.toIso8601String();
}
