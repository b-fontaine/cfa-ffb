import 'dart:async';

import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';

/// Un **appareil** devant un serveur partagé : le [DocumentStore] d'un
/// téléphone ou d'un navigateur dont la connexion se coupe et revient, devant
/// le `InMemoryDocumentStore` que tous les appareils d'un scénario partagent.
///
/// En ligne, il délègue au serveur. **Hors ligne** :
/// - les lectures qui demandent le serveur (`get`, `list`, `query`,
///   `createIfAbsent`) échouent en `unavailable` ;
/// - les flux (`watch…`) cessent de livrer ; le dernier état reçu pendant la
///   coupure est **retenu** et livré à la reconnexion (le SDK rejoue l'état du
///   serveur à la reprise) ;
/// - les lots d'écriture sont **mis en file** (ordre conservé) et envoyés à la
///   reconnexion.
///
/// **Limites de ce double** (dites dans `testing.md`) : pas de cache local
/// (une écriture hors ligne n'est pas visible sur l'appareil avant la
/// reconnexion, `peek` rend toujours `null`) ; aucune règle de sécurité ; la
/// coupure est tout ou rien. Ce que le vrai SDK fait hors ligne se prouve par
/// la fumée du build compilé et le parcours navigateur.
class DeviceDocumentStore implements DocumentStore {
  DeviceDocumentStore(this.server);

  /// Le serveur partagé.
  final InMemoryDocumentStore server;

  var _online = true;
  final List<List<WriteOp>> _queued = [];
  final List<_Gate<Object?>> _gates = [];

  /// L'appareil est connecté.
  bool get online => _online;

  /// Combien de lots attendent la reconnexion.
  int get queuedBatches => _queued.length;

  /// Coupe la connexion.
  void goOffline() => _online = false;

  /// Rétablit la connexion : les lots en file partent dans l'ordre, puis les
  /// flux reçoivent l'état du serveur.
  Future<void> goOnline() async {
    _online = true;
    final queued = _queued.toList();
    _queued.clear();
    for (final batch in queued) {
      await server.commit(batch);
    }
    for (final gate in _gates.toList()) {
      gate.flush();
    }
  }

  void _requireOnline() {
    if (!_online) {
      throw const StoreFailure(StoreFailureCode.unavailable, 'hors ligne');
    }
  }

  @override
  Future<StoredDocument?> get(String path) async {
    _requireOnline();
    return await server.get(path);
  }

  @override
  Future<StoredDocument?> peek(String path) async => null;

  @override
  Future<List<StoredDocument>> list(String collection) async {
    _requireOnline();
    return await server.list(collection);
  }

  @override
  Future<List<StoredDocument>> query(
    String collection,
    QueryFilter filter,
  ) async {
    _requireOnline();
    return await server.query(collection, filter);
  }

  @override
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) async {
    _requireOnline();
    return await server.collectionGroup(
      collectionId,
      field: field,
      equalTo: equalTo,
    );
  }

  @override
  Future<bool> createIfAbsent(String path, Fields fields) async {
    _requireOnline();
    return await server.createIfAbsent(path, fields);
  }

  @override
  Future<void> commit(List<WriteOp> operations) async {
    checkBatchSize(operations);
    if (_online) return await server.commit(operations);
    _queued.add(List.of(operations));
  }

  @override
  Stream<DocumentUpdate> watchDocument(String path) =>
      _gated(server.watchDocument(path));

  @override
  Stream<CollectionUpdate> watchCollection(String collection) =>
      _gated(server.watchCollection(collection));

  @override
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) =>
      _gated(server.watchQuery(collection, filter));

  Stream<T> _gated<T>(Stream<T> source) {
    final gate = _Gate<T>(source, () => _online, _gates.remove);
    _gates.add(gate as _Gate<Object?>);
    return gate.stream;
  }
}

/// Un flux qui ne livre que connecté : retient le dernier événement reçu
/// pendant la coupure.
class _Gate<T> {
  _Gate(this._source, this._online, this._drop) {
    _controller = StreamController<T>(onListen: _listen, onCancel: _cancel);
  }

  final Stream<T> _source;
  final bool Function() _online;
  final void Function(_Gate<Object?>) _drop;
  late final StreamController<T> _controller;
  StreamSubscription<T>? _subscription;
  ({T? value, Object? error, StackTrace? stack})? _held;
  var _failed = false;
  var _ended = false;

  Stream<T> get stream => _controller.stream;

  void _listen() {
    _subscription = _source.listen(
      (event) => _deliver(value: event),
      onError: (Object error, StackTrace stack) =>
          _deliver(error: error, stack: stack),
      onDone: _onDone,
    );
  }

  /// La fin du flux du serveur : différée tant qu'un événement est retenu.
  void _onDone() {
    if (_held == null && _online()) {
      unawaited(_controller.close());
    } else {
      _ended = true;
    }
  }

  void _deliver({T? value, Object? error, StackTrace? stack}) {
    if (!_online()) {
      _held = (value: value, error: error, stack: stack);
      return;
    }
    _emit((value: value, error: error, stack: stack));
  }

  void _emit(({T? value, Object? error, StackTrace? stack}) event) {
    if (_controller.isClosed || _failed) return;
    final error = event.error;
    if (error != null) {
      _failed = true;
      _controller.addError(error, event.stack);
      unawaited(_controller.close());
    } else {
      _controller.add(event.value as T);
    }
  }

  void flush() {
    final held = _held;
    _held = null;
    if (held != null) _emit(held);
    if (_ended && !_controller.isClosed) unawaited(_controller.close());
  }

  Future<void> _cancel() async {
    _drop(this as _Gate<Object?>);
    await _subscription?.cancel();
    _subscription = null;
  }
}
