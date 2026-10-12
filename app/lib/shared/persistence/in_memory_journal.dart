import 'dart:async';

/// Journal d'annulation d'une unité de travail en mémoire.
///
/// `InMemoryUnitOfWork` exécute son corps dans une zone portant un journal ;
/// chaque écriture des dépôts en mémoire y inscrit son annulation (voir
/// [InMemoryJournaledMap]). Si le corps échoue, les annulations sont rejouées
/// en ordre inverse : mêmes garanties que la transaction SQLite, sans que
/// les dépôts se connaissent entre eux.
class InMemoryJournal {
  static const _zoneKey = #billardCfaInMemoryJournal;

  final List<void Function()> _undo = [];

  /// Inscrit [undo] dans l'unité de travail en cours (sans effet hors unité).
  static void record(void Function() undo) {
    final journal = Zone.current[_zoneKey] as InMemoryJournal?;
    journal?._undo.add(undo);
  }

  /// Exécute [body] ; en cas d'échec, annule ses écritures et propage.
  /// Une unité imbriquée confie ses annulations à l'unité englobante.
  Future<T> run<T>(Future<T> Function() body) async {
    final outer = Zone.current[_zoneKey] as InMemoryJournal?;
    final T value;
    try {
      value = await runZoned(body, zoneValues: {_zoneKey: this});
    } on Object {
      for (final undo in _undo.reversed) {
        undo();
      }
      rethrow;
    }
    outer?._undo.addAll(_undo);
    return value;
  }
}

/// Écritures d'une table en mémoire qui s'inscrivent au journal.
extension InMemoryJournaledMap<K, V> on Map<K, V> {
  /// Écrit [value] sous [key]; l'ancienne valeur (ou l'absence) est rétablie
  /// si l'unité de travail en cours échoue.
  void journaledPut(K key, V value) {
    if (containsKey(key)) {
      final previous = this[key] as V;
      InMemoryJournal.record(() => this[key] = previous);
    } else {
      InMemoryJournal.record(() => remove(key));
    }
    this[key] = value;
  }

  /// Retire [key] ; l'entrée est rétablie si l'unité de travail échoue.
  void journaledRemove(K key) {
    if (!containsKey(key)) return;
    final previous = this[key] as V;
    InMemoryJournal.record(() => this[key] = previous);
    remove(key);
  }
}
