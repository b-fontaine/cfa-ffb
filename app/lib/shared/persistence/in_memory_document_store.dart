import 'dart:async';

import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/write_values.dart';
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

  /// Les flux demandés, dans l'ordre : `document <chemin>`, `collection <c>`,
  /// `query <c> <champ> = <valeur>`, `query <c> <champ> any <valeurs>` ou
  /// `query <c> <champ>=<valeur>,…` (assertions : ce qu'un rôle a le droit de
  /// suivre, les règles refusant toute autre écoute).
  final List<String> watchLog = [];

  /// Les flux ouverts et non annulés (assertions : aucune fuite d'abonnement).
  int get activeWatchers => _watchers.length;

  final List<_Watcher> _watchers = [];

  /// Préfixes de chemins dont les règles refusent la lecture (accès perdu).
  final Map<String, StoreFailureCode> _revoked = {};

  /// Retire l'accès en lecture à tout chemin sous [pathPrefix] (un membre
  /// retiré du club, un rôle rétrogradé) : les flux ouverts dessus reçoivent
  /// un [StoreFailure] et se **ferment**, comme l'écoute d'un SDK dont les
  /// règles viennent de changer ; toute lecture ou écoute ultérieure y échoue
  /// jusqu'à [restore]. Les écritures ne sont pas concernées (les règles ne
  /// sont pas émulées ici : `failing` les fait échouer).
  void revoke(
    String pathPrefix, [
    StoreFailureCode code = StoreFailureCode.permissionDenied,
  ]) {
    _revoked[pathPrefix] = code;
    for (final watcher in _watchers.toList()) {
      if (watcher.path.startsWith(pathPrefix)) {
        watcher.fail(StoreFailure(code, 'accès retiré : $pathPrefix'));
      }
    }
  }

  /// Rend l'accès retiré par [revoke] (les flux fermés restent fermés).
  void restore(String pathPrefix) => _revoked.remove(pathPrefix);

  /// Les documents, par chemin (assertions et amorçage des scénarios).
  Map<String, Fields> get documents => {
    for (final entry in _documents.entries) entry.key: _copy(entry.value),
  };

  /// Écrit directement un document (amorçage), sans passer par un lot.
  void seed(String path, Fields fields) {
    _documents[path] = _resolve(_copy(fields), const {});
    _notify();
  }

  /// Supprime directement un document (amorçage), sans passer par un lot.
  void remove(String path) {
    _documents.remove(path);
    _notify();
  }

  /// Le document [path] tel qu'il est stocké, `null` s'il n'existe pas.
  Fields? read(String path) {
    final fields = _documents[path];
    return fields == null ? null : _copy(fields);
  }

  void _check([String? path]) {
    final code = failing;
    if (code != null) throw StoreFailure(code, 'échec simulé');
    if (path != null) _checkReadable(path);
  }

  void _checkReadable(String path) {
    for (final entry in _revoked.entries) {
      if (path.startsWith(entry.key)) {
        throw StoreFailure(entry.value, 'accès retiré : ${entry.key}');
      }
    }
  }

  @override
  Future<StoredDocument?> get(String path) async {
    reads++;
    _check(path);
    final fields = _documents[path];
    return fields == null ? null : StoredDocument(path, _copy(fields));
  }

  /// Le cache d'un double, c'est son contenu : la lecture ne passe PAS par
  /// [get] (que les tests surchargent pour simuler le hors ligne) ni par
  /// l'échec simulé.
  @override
  Future<StoredDocument?> peek(String path) async {
    final fields = _documents[path];
    return fields == null ? null : StoredDocument(path, _copy(fields));
  }

  @override
  Future<List<StoredDocument>> list(String collection) async {
    reads++;
    _check('$collection/');
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
    _check('$collection/');
    return _matching(collection, filter);
  }

  List<StoredDocument> _matching(String collection, QueryFilter? filter) {
    final prefix = '$collection/';
    final paths = _documents.keys.where((path) {
      if (!path.startsWith(prefix) ||
          path.substring(prefix.length).contains('/')) {
        return false;
      }
      if (filter == null) return true;
      final fields = _documents[path]!;
      final value = fields[filter.field];
      return switch (filter) {
        FieldEquals(value: final wanted) => value == wanted,
        FieldArrayContainsAny(:final values) =>
          value is List<Object?> && value.any(values.contains),
        AllEqual(:final clauses) => clauses.every(
          (clause) => fields[clause.field] == clause.value,
        ),
      };
    }).toList()..sort();
    return [
      for (final path in paths) StoredDocument(path, _copy(_documents[path]!)),
    ];
  }

  @override
  Stream<DocumentUpdate> watchDocument(String path) {
    watchLog.add('document $path');
    return _watchDocument(path);
  }

  Stream<DocumentUpdate> _watchDocument(String path) => _watch(
    path,
    () => DocumentUpdate(
      _documents[path] == null
          ? null
          : StoredDocument(path, _copy(_documents[path]!)),
    ),
    (update) =>
        _snapshotKey(update.document == null ? null : [update.document!]),
  );

  @override
  Stream<CollectionUpdate> watchCollection(String collection) {
    watchLog.add('collection $collection');
    return _watchCollection(collection);
  }

  Stream<CollectionUpdate> _watchCollection(String collection) => _watch(
    '$collection/',
    () => CollectionUpdate(_matching(collection, null)),
    (update) => _snapshotKey(update.documents),
  );

  @override
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) {
    watchLog.add('query $collection ${_describeFilter(filter)}');
    return _watchQuery(collection, filter);
  }

  static String _describeFilter(QueryFilter filter) => switch (filter) {
    FieldEquals(:final field, :final value) => '$field=$value',
    FieldArrayContainsAny(:final field, :final values) =>
      '$field any ${values.join('|')}',
    AllEqual(:final clauses) => clauses.map(_describeFilter).join(','),
  };

  Stream<CollectionUpdate> _watchQuery(String collection, QueryFilter filter) =>
      _watch(
        '$collection/',
        () => CollectionUpdate(_matching(collection, filter)),
        (update) => _snapshotKey(update.documents),
      );

  /// Un flux : l'état courant à l'abonnement, puis chaque état **différent**
  /// du précédent après un changement du stock. Un accès retiré ou un échec
  /// simulé à l'abonnement arrive en erreur, puis le flux se ferme.
  Stream<T> _watch<T>(
    String path,
    T Function() snapshot,
    Object Function(T) key,
  ) {
    late final StreamController<T> controller;
    late final _TypedWatcher<T> watcher;
    controller = StreamController<T>(
      onListen: () {
        try {
          _check(path);
        } on StoreFailure catch (failure) {
          controller.addError(failure);
          unawaited(controller.close());
          return;
        }
        _watchers.add(watcher);
        watcher.emit(force: true);
      },
      onCancel: () {
        _watchers.remove(watcher);
      },
    );
    watcher = _TypedWatcher<T>(
      path,
      controller,
      snapshot,
      key,
      _watchers.remove,
    );
    return controller.stream;
  }

  void _notify() {
    for (final watcher in _watchers.toList()) {
      watcher.emit();
    }
  }

  /// Représentation comparable d'un état : chemins et champs.
  static Object _snapshotKey(List<StoredDocument>? documents) => [
    for (final document in documents ?? const <StoredDocument>[])
      '${document.path}\u0000${_describe(document.fields)}',
  ].join('\u0001');

  static String _describe(Object? value) {
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList()..sort();
      final parts = [for (final key in keys) '$key:${_describe(value[key])}'];
      return '{${parts.join(',')}}';
    }
    if (value is List<Object?>) return '[${value.map(_describe).join(',')}]';
    if (value is DateTime) return 'D${value.microsecondsSinceEpoch}';
    return '${value.runtimeType}:$value';
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
  Future<bool> createIfAbsent(String path, Fields fields) async {
    commits++;
    _check();
    if (_documents.containsKey(path)) return false;
    _documents[path] = _resolve(_copy(fields), const {});
    _notify();
    return true;
  }

  @override
  Future<void> commit(List<WriteOp> operations) async {
    commits++;
    _check();
    checkBatchSize(operations);
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
    _notify();
  }

  Fields _resolve(Fields fields, Fields current) =>
      resolveWriteValues(fields, current, serverNow);

  static Fields _copy(Fields fields) => copyFields(fields);
}

/// Un flux ouvert sur le stock : sait se recalculer et n'émet que si l'état a
/// changé.
abstract class _Watcher {
  /// Chemin (ou préfixe de collection) suivi.
  String get path;

  /// Envoie l'état courant (toujours si [force], sinon s'il a changé).
  void emit({bool force = false});

  /// Termine le flux par [failure].
  void fail(StoreFailure failure);
}

class _TypedWatcher<T> implements _Watcher {
  _TypedWatcher(
    this.path,
    this._controller,
    this._snapshot,
    this._key,
    this._drop,
  );

  @override
  final String path;
  final StreamController<T> _controller;
  final T Function() _snapshot;
  final Object Function(T) _key;
  final void Function(_Watcher) _drop;
  Object? _last;

  @override
  void emit({bool force = false}) {
    if (_controller.isClosed) return;
    final value = _snapshot();
    final key = _key(value);
    if (!force && key == _last) return;
    _last = key;
    _controller.add(value);
  }

  @override
  void fail(StoreFailure failure) {
    _drop(this);
    if (_controller.isClosed) return;
    _controller.addError(failure);
    unawaited(_controller.close());
  }
}
