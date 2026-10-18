import 'package:billard_cfa/shared/persistence/document_store.dart';

/// Résout les valeurs d'écriture d'un document ([ServerTimestamp],
/// [ArrayUnion], [ArrayRemove]) contre son état [current], comme le serveur
/// le fera. Partagé par le double en mémoire et par la lecture de ses propres
/// écritures dans une unité de travail.
Fields resolveWriteValues(
  Fields incoming,
  Fields current,
  Object? Function() serverNow,
) => {
  for (final entry in incoming.entries)
    entry.key: switch (entry.value) {
      ServerTimestamp() => serverNow(),
      ArrayUnion(:final values) => [
        ..._listOf(current[entry.key]),
        for (final value in values)
          if (!_listOf(current[entry.key]).contains(value)) value,
      ],
      ArrayRemove(:final values) => [
        for (final item in _listOf(current[entry.key]))
          if (!values.contains(item)) item,
      ],
      final other => other,
    },
};

List<Object?> _listOf(Object? value) =>
    value is List<Object?> ? value : const [];

/// Copie profonde des champs (listes et tables comprises).
Fields copyFields(Fields fields) => {
  for (final entry in fields.entries) entry.key: _copyValue(entry.value),
};

Object? _copyValue(Object? value) => switch (value) {
  final List<Object?> list => [for (final item in list) _copyValue(item)],
  final Map<String, Object?> map => copyFields(map),
  _ => value,
};
