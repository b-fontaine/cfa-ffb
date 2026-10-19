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

  /// Annonces retenues jusqu'à la fin de l'unité, par table.
  final Map<Object, void Function()> _deferred = {};

  /// Inscrit [undo] dans l'unité de travail en cours (sans effet hors unité).
  static void record(void Function() undo) {
    final journal = Zone.current[_zoneKey] as InMemoryJournal?;
    journal?._undo.add(undo);
  }

  /// Annonce une modification de [owner] (une table observée) : aussitôt hors
  /// unité de travail, **à la fin de l'unité** dans une unité (une seule fois
  /// par table, annulation comprise), pour qu'un abonné ne voie jamais un état
  /// à moitié appliqué.
  static void announce(Object owner, void Function() emit) {
    final journal = Zone.current[_zoneKey] as InMemoryJournal?;
    if (journal == null) {
      emit();
    } else {
      journal._deferred[owner] = emit;
    }
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
      _release(outer);
      rethrow;
    }
    outer?._undo.addAll(_undo);
    _release(outer);
    return value;
  }

  /// Passe les annonces retenues à l'unité englobante, ou les émet si c'est
  /// la plus extérieure.
  void _release(InMemoryJournal? outer) {
    if (outer != null) {
      outer._deferred.addAll(_deferred);
    } else {
      for (final emit in _deferred.values) {
        emit();
      }
    }
    _deferred.clear();
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
