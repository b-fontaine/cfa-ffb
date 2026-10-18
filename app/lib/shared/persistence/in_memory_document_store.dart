import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:injectable/injectable.dart';

/// Stock de documents en mémoire (tests, scénarios BDD) : même contrat que
/// Firestore pour ce que les dépôts utilisent, **sans** les règles de
/// sécurité (elles sont testées contre l'émulateur, `scripts/rules_test/`).
@LazySingleton(as: DocumentStore, env: [Environment.test])
class InMemoryDocumentStore implements DocumentStore {
  InMemoryDocumentStore();

  final Map<String, Fields> _documents = {};

  /// L'heure du « serveur » (les scénarios y branchent l'horloge figée).
  DateTime Function() serverNow = DateTime.now;

  /// Quand il est renseigné, toute opération échoue avec ce code (réseau
  /// coupé : `unavailable` ; règles : `permissionDenied`).
  StoreFailureCode? failing;

  /// Combien de lectures et de lots ont été demandés (assertions).
  int reads = 0;
  int commits = 0;

  /// Les filtres des requêtes demandées, dans l'ordre (assertions).
  final List<QueryFilter> queryLog = [];

  /// Les documents, par chemin (assertions et amorçage des scénarios).
  Map<String, Fields> get documents => {
    for (final entry in _documents.entries) entry.key: _copy(entry.value),
  };

  /// Écrit directement un document (amorçage), sans passer par un lot.
  void seed(String path, Fields fields) =>
      _documents[path] = _resolve(_copy(fields), const {});

  /// Supprime directement un document (amorçage), sans passer par un lot.
  void remove(String path) => _documents.remove(path);

  /// Le document [path] tel qu'il est stocké, `null` s'il n'existe pas.
  Fields? read(String path) {
    final fields = _documents[path];
    return fields == null ? null : _copy(fields);
  }

  void _check() {
    final code = failing;
    if (code != null) throw StoreFailure(code, 'échec simulé');
  }

  @override
  Future<StoredDocument?> get(String path) async {
    reads++;
    _check();
    final fields = _documents[path];
    return fields == null ? null : StoredDocument(path, _copy(fields));
  }

  @override
  Future<List<StoredDocument>> list(String collection) async {
    reads++;
    _check();
    final prefix = '$collection/';
    final paths =
        _documents.keys
            .where(
              (path) =>
                  path.startsWith(prefix) &&
                  !path.substring(prefix.length).contains('/'),
            )
            .toList()
          ..sort();
    return [
      for (final path in paths) StoredDocument(path, _copy(_documents[path]!)),
    ];
  }

  @override
  Future<List<StoredDocument>> query(
    String collection,
    QueryFilter filter,
  ) async {
    reads++;
    queryLog.add(filter);
    _check();
    final prefix = '$collection/';
    final paths = _documents.keys.where((path) {
      if (!path.startsWith(prefix) ||
          path.substring(prefix.length).contains('/')) {
        return false;
      }
      final value = _documents[path]![filter.field];
      return switch (filter) {
        FieldEquals(value: final wanted) => value == wanted,
        FieldArrayContainsAny(:final values) =>
          value is List<Object?> && value.any(values.contains),
      };
    }).toList()..sort();
    return [
      for (final path in paths) StoredDocument(path, _copy(_documents[path]!)),
    ];
  }

  @override
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) async {
    reads++;
    _check();
    final paths = _documents.keys.where((path) {
      final segments = path.split('/');
      return segments.length.isEven &&
          segments[segments.length - 2] == collectionId &&
          _documents[path]![field] == equalTo;
    }).toList()..sort();
    return [
      for (final path in paths) StoredDocument(path, _copy(_documents[path]!)),
    ];
  }

  @override
  Future<void> commit(List<WriteOp> operations) async {
    commits++;
    _check();
    // Tout ou rien : on valide d'abord, on applique ensuite.
    final staged = {..._documents};
    for (final operation in operations) {
      switch (operation) {
        case SetOp(:final path, :final fields, :final merge):
          final current = merge
              ? staged[path] ?? const {}
              : const <String, Object?>{};
          staged[path] = {...current, ..._resolve(_copy(fields), current)};
        case UpdateOp(:final path, :final fields):
          final current = staged[path];
          if (current == null) {
            throw StoreFailure(StoreFailureCode.notFound, path);
          }
          staged[path] = {...current, ..._resolve(_copy(fields), current)};
        case DeleteOp(:final path):
          staged.remove(path);
      }
    }
    _documents
      ..clear()
      ..addAll(staged);
  }

  Fields _resolve(Fields fields, Fields current) => {
    for (final entry in fields.entries)
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

  static List<Object?> _listOf(Object? value) =>
      value is List<Object?> ? value : const [];

  static Fields _copy(Fields fields) => {
    for (final entry in fields.entries) entry.key: _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) => switch (value) {
    final List<Object?> list => [for (final item in list) _copyValue(item)],
    final Map<String, Object?> map => _copy(map),
    _ => value,
  };
}
