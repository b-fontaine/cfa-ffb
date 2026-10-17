import 'dart:convert';

/// Sérialisation des deux cartes d'une séance guidée en cours (compteurs et
/// grille « acquis »), stockées en texte JSON dans `run_progress_entries`.
///
/// L'écriture est stable (clés et indices triés). La lecture est stricte :
/// tout ce qui n'est pas exactement de la forme attendue lève une
/// [FormatException], et la ligne est alors jugée illisible (supprimée par le
/// dépôt, jamais d'exception à l'ouverture de l'application).
abstract final class RunProgressJson {
  /// `{"initiation": 3}`, clés triées.
  static String encodeCounts(Map<String, int> counts) =>
      jsonEncode({for (final key in _sorted(counts.keys)) key: counts[key]});

  static Map<String, int> decodeCounts(String text) {
    final decoded = _object(text);
    return {
      for (final entry in decoded.entries)
        entry.key: switch (entry.value) {
          final int count => count,
          _ => throw const FormatException('compteur non entier'),
        },
    };
  }

  /// `{"initiation": [0, 2]}`, clés et indices triés.
  static String encodeChecked(Map<String, Set<int>> checked) => jsonEncode({
    for (final key in _sorted(checked.keys))
      key: (checked[key]!.toList()..sort()),
  });

  static Map<String, Set<int>> decodeChecked(String text) {
    final decoded = _object(text);
    return {
      for (final entry in decoded.entries)
        entry.key: switch (entry.value) {
          final List<Object?> indices => {
            for (final index in indices)
              switch (index) {
                final int value => value,
                _ => throw const FormatException('critère non entier'),
              },
          },
          _ => throw const FormatException('grille non liste'),
        },
    };
  }

  static Map<String, Object?> _object(String text) =>
      switch (jsonDecode(text)) {
        final Map<String, Object?> map => map,
        _ => throw const FormatException('objet JSON attendu'),
      };

  static List<String> _sorted(Iterable<String> keys) => keys.toList()..sort();
}
