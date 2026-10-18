import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/write_values.dart';

/// Les écritures d'une unité de travail, en attente du lot unique qui les
/// applique (ADR 0024, décision 19).
///
/// - Plusieurs écritures d'un **même document** n'en font qu'une, dans
///   l'ordre : un lot ne doit pas porter deux écritures du même chemin (les
///   règles évalueraient chacune contre l'état d'avant le lot) ;
/// - [overlay] rend l'état d'un document **tel que le lot le laissera** : un
///   dépôt qui relit un document qu'il vient d'écrire le voit (seul `get` ;
///   les listes et les requêtes ne voient pas les écritures en attente).
final class PendingWrites {
  final Map<String, WriteOp> _byPath = {};

  /// Les écritures, dans l'ordre de première écriture de chaque document.
  List<WriteOp> get operations => List.unmodifiable(_byPath.values);

  void add(WriteOp operation) {
    final earlier = _byPath[operation.path];
    _byPath[operation.path] = earlier == null
        ? operation
        : _combine(earlier, operation);
  }

  /// L'état de [path] une fois les écritures en attente appliquées à [stored]
  /// (l'état lu sur le serveur) ; `null` si le document n'existera pas.
  Fields? overlay(String path, Fields? stored) {
    final pending = _byPath[path];
    if (pending == null) return stored;
    // La date du serveur n'est pas connue avant le lot : l'horloge locale la
    // remplace pour cette seule lecture.
    const now = DateTime.now;
    switch (pending) {
      case DeleteOp():
        return null;
      case SetOp(:final fields, merge: false):
        return resolveWriteValues(copyFields(fields), const {}, now);
      case SetOp(:final fields, merge: true):
        final base = stored ?? const <String, Object?>{};
        return {...base, ...resolveWriteValues(copyFields(fields), base, now)};
      case UpdateOp(:final fields):
        if (stored == null) return null;
        return {
          ...stored,
          ...resolveWriteValues(copyFields(fields), stored, now),
        };
    }
  }

  static WriteOp _combine(WriteOp earlier, WriteOp later) {
    if (later is DeleteOp) return later;
    if (earlier is DeleteOp) {
      if (later is UpdateOp) {
        throw StoreFailure(StoreFailureCode.notFound, later.path);
      }
      return later;
    }
    final fields = switch (later) {
      SetOp(:final fields) || UpdateOp(:final fields) => fields,
      DeleteOp() => const <String, Object?>{},
    };
    if (later is SetOp && !later.merge) return later;
    final base = switch (earlier) {
      SetOp(:final fields) || UpdateOp(:final fields) => fields,
      DeleteOp() => const <String, Object?>{},
    };
    final merged = _mergeFields(earlier.path, base, fields);
    // Une mise à jour exige le document : elle reste exigée.
    if (earlier is UpdateOp) return UpdateOp(earlier.path, merged);
    return SetOp(earlier.path, merged, merge: (earlier as SetOp).merge);
  }

  static Fields _mergeFields(String path, Fields earlier, Fields later) {
    final merged = {...earlier};
    for (final entry in later.entries) {
      final before = earlier[entry.key];
      final after = entry.value;
      merged[entry.key] = switch ((before, after)) {
        (ArrayUnion(values: final a), ArrayUnion(values: final b)) =>
          ArrayUnion([
            ...a,
            for (final value in b)
              if (!a.contains(value)) value,
          ]),
        (ArrayRemove(values: final a), ArrayRemove(values: final b)) =>
          ArrayRemove([...a, ...b]),
        (final List<Object?> a, ArrayUnion(values: final b)) => [
          ...a,
          for (final value in b)
            if (!a.contains(value)) value,
        ],
        (final List<Object?> a, ArrayRemove(values: final b)) => [
          for (final item in a)
            if (!b.contains(item)) item,
        ],
        (ArrayUnion() || ArrayRemove(), ArrayUnion() || ArrayRemove()) =>
          throw StoreFailure(
            StoreFailureCode.other,
            'conflicting array operations on ${entry.key} of $path',
          ),
        _ => after,
      };
    }
    return merged;
  }
}
