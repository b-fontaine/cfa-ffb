import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/relay_stream.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Un document tel que le SDK le rend : son chemin et ses champs bruts
/// (`Timestamp` compris).
typedef RawDocument = ({String path, Map<String, dynamic> data});

/// D'où vient un instantané du SDK (`SnapshotMetadata` de cloud_firestore).
typedef RawMetadata = ({bool fromCache, bool hasPendingWrites});

/// L'état d'un document suivi en flux : `data` nul s'il n'existe pas.
typedef RawDocumentEvent = ({Map<String, dynamic>? data, RawMetadata metadata});

/// L'état d'une collection ou d'une requête suivie en flux.
typedef RawCollectionEvent = ({
  List<RawDocument> documents,
  RawMetadata metadata,
});

/// Les appels que `FirestoreDocumentStore` fait au SDK, sur des types
/// simples : de quoi tester tout le reste (traduction des valeurs et des
/// échecs) sans plugin ni réseau.
abstract interface class FirestoreAccess {
  Future<Map<String, dynamic>?> readDocument(String path);

  /// Comme [readDocument], **dans le cache local seulement** : `null` si le
  /// document n'y est pas, sans attendre le réseau ni échouer hors ligne.
  Future<Map<String, dynamic>?> peekDocument(String path);

  /// Comme [readDocument], **au serveur seulement** : jamais le cache, et
  /// `unavailable` hors ligne (au lieu de la valeur du cache).
  Future<Map<String, dynamic>?> readDocumentFromServer(String path);

  Future<List<RawDocument>> readCollection(String path);

  /// Une collection filtrée sur un champ : égalité ([contains] faux, [value]
  /// la valeur) ou « contient l'un de » ([contains] vrai, [value] la liste).
  Future<List<RawDocument>> readQuery(
    String path,
    String field, {
    required bool contains,
    required Object? value,
  });

  /// Une collection filtrée par plusieurs égalités sur des champs différents.
  Future<List<RawDocument>> readQueryAll(
    String path,
    Map<String, Object?> equalities,
  );

  Future<List<RawDocument>> readGroup(
    String collectionId,
    String field,
    Object? equalTo,
  );

  /// Les écoutes temps réel (`snapshots()`) : l'état courant puis un état par
  /// changement. Une erreur du SDK (`FirebaseException`) arrive sur le flux ;
  /// l'écoute est alors terminée côté serveur.
  Stream<RawDocumentEvent> watchDocument(String path);

  Stream<RawCollectionEvent> watchCollection(String path);

  /// Comme [readQuery], en flux.
  Stream<RawCollectionEvent> watchQuery(
    String path,
    String field, {
    required bool contains,
    required Object? value,
  });

  /// Comme [readQueryAll], en flux.
  Stream<RawCollectionEvent> watchQueryAll(
    String path,
    Map<String, Object?> equalities,
  );

  /// Applique les écritures en **un seul lot** ; les champs sont déjà au
  /// format du SDK.
  Future<void> writeBatch(List<RawWrite> writes);

  /// Crée le document dans **une transaction** (lecture, puis écriture s'il
  /// est absent) ; `false` s'il existe déjà. Un lot ne sait pas « créer » :
  /// il écrit par-dessus, ce qui est une mise à jour pour les règles.
  Future<bool> createDocument(String path, Map<String, Object?> data);
}

/// Une écriture déjà traduite : `set`, `setMerge`, `update` (champs) ou
/// `delete` (sans
/// champs).
typedef RawWrite = ({
  String path,
  RawWriteKind kind,
  Map<String, Object?>? data,
});

enum RawWriteKind { set, setMerge, update, delete }

/// Les appels directs au SDK `cloud_firestore` : seul code de l'application qui
/// le touche (règle 9), volontairement minimal. N'est appelé qu'une fois
/// Firebase initialisé ; `FirebaseFirestore.instance` n'est lu qu'à l'appel.
/// Son comportement réel (règles, lot atomique, requête de groupe de
/// collections) est vérifié contre l'émulateur par `scripts/rules_test/`, qui
/// joue les mêmes opérations avec le SDK web.
class FirestoreSdkAccess implements FirestoreAccess {
  FirestoreSdkAccess({
    FirebaseFirestore Function()? firestore,
    this._readFromCache,
    this._readFromServer,
  }) : _firestore = firestore ?? (() => FirebaseFirestore.instance);

  final FirebaseFirestore Function() _firestore;
  final Future<DocumentSnapshot<Map<String, dynamic>>> Function(String path)?
  _readFromCache;
  final Future<DocumentSnapshot<Map<String, dynamic>>> Function(String path)?
  _readFromServer;

  @override
  Future<Map<String, dynamic>?> readDocument(String path) async {
    final snapshot = await _firestore().doc(path).get();
    return snapshot.exists ? snapshot.data() : null;
  }

  @override
  Future<Map<String, dynamic>?> peekDocument(String path) async {
    try {
      final snapshot = await (_readFromCache ?? _cacheRead)(path);
      return snapshot.exists ? snapshot.data() : null;
    } on FirebaseException catch (error) {
      // Absent du cache : le SDK le dit par `unavailable`, comme hors ligne.
      if (error.code == 'unavailable') return null;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> readDocumentFromServer(String path) async {
    final snapshot = await (_readFromServer ?? _serverRead)(path);
    return snapshot.exists ? snapshot.data() : null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _serverRead(String path) =>
      _firestore().doc(path).get(const GetOptions(source: Source.server));

  Future<DocumentSnapshot<Map<String, dynamic>>> _cacheRead(String path) =>
      _firestore().doc(path).get(const GetOptions(source: Source.cache));

  @override
  Future<List<RawDocument>> readCollection(String path) async =>
      _raw(await _firestore().collection(path).get());

  @override
  Future<List<RawDocument>> readQuery(
    String path,
    String field, {
    required bool contains,
    required Object? value,
  }) async {
    final collection = _firestore().collection(path);
    final query = contains
        ? collection.where(field, arrayContainsAny: value! as List<Object?>)
        : collection.where(field, isEqualTo: value);
    return _raw(await query.get());
  }

  @override
  Future<List<RawDocument>> readQueryAll(
    String path,
    Map<String, Object?> equalities,
  ) async {
    Query<Map<String, dynamic>> query = _firestore().collection(path);
    for (final entry in equalities.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }
    return _raw(await query.get());
  }

  @override
  Future<List<RawDocument>> readGroup(
    String collectionId,
    String field,
    Object? equalTo,
  ) async => _raw(
    await _firestore()
        .collectionGroup(collectionId)
        .where(field, isEqualTo: equalTo)
        .get(),
  );

  @override
  Stream<RawDocumentEvent> watchDocument(String path) => _firestore()
      .doc(path)
      .snapshots()
      .map(
        (snapshot) => (
          data: snapshot.exists ? snapshot.data() : null,
          metadata: _metadata(snapshot.metadata),
        ),
      );

  @override
  Stream<RawCollectionEvent> watchCollection(String path) =>
      _events(_firestore().collection(path).snapshots());

  @override
  Stream<RawCollectionEvent> watchQuery(
    String path,
    String field, {
    required bool contains,
    required Object? value,
  }) {
    final collection = _firestore().collection(path);
    return _events(
      (contains
              ? collection.where(
                  field,
                  arrayContainsAny: value! as List<Object?>,
                )
              : collection.where(field, isEqualTo: value))
          .snapshots(),
    );
  }

  @override
  Stream<RawCollectionEvent> watchQueryAll(
    String path,
    Map<String, Object?> equalities,
  ) {
    Query<Map<String, dynamic>> query = _firestore().collection(path);
    for (final entry in equalities.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }
    return _events(query.snapshots());
  }

  static Stream<RawCollectionEvent> _events(
    Stream<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) => snapshots.map(
    (snapshot) =>
        (documents: _raw(snapshot), metadata: _metadata(snapshot.metadata)),
  );

  static RawMetadata _metadata(SnapshotMetadata metadata) => (
    fromCache: metadata.isFromCache,
    hasPendingWrites: metadata.hasPendingWrites,
  );

  @override
  Future<void> writeBatch(List<RawWrite> writes) async {
    final firestore = _firestore();
    final batch = firestore.batch();
    for (final write in writes) {
      final reference = firestore.doc(write.path);
      switch (write.kind) {
        case RawWriteKind.set:
          batch.set(reference, write.data!);
        case RawWriteKind.setMerge:
          batch.set(reference, write.data!, SetOptions(merge: true));
        case RawWriteKind.update:
          batch.update(reference, write.data!);
        case RawWriteKind.delete:
          batch.delete(reference);
      }
    }
    await batch.commit();
  }

  @override
  Future<bool> createDocument(String path, Map<String, Object?> data) =>
      _firestore().runTransaction((transaction) async {
        final reference = _firestore().doc(path);
        if ((await transaction.get(reference)).exists) return false;
        transaction.set(reference, data);
        return true;
      });

  static List<RawDocument> _raw(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      [
        for (final document in snapshot.docs)
          (path: document.reference.path, data: document.data()),
      ];
}

/// [DocumentStore] sur Firestore : traduit les valeurs (dates, date du
/// serveur, listes, tables) et les échecs du SDK. Les règles de sécurité
/// s'appliquent côté serveur : un refus arrive en `permission-denied`, traduit
/// en [StoreFailureCode.permissionDenied].
class FirestoreDocumentStore implements DocumentStore {
  FirestoreDocumentStore({FirestoreAccess? access})
    : _access = access ?? FirestoreSdkAccess();

  final FirestoreAccess _access;

  @override
  Future<StoredDocument?> get(String path) => _guard(() async {
    final data = await _access.readDocument(path);
    return data == null ? null : StoredDocument(path, decodeFields(data));
  });

  @override
  Future<StoredDocument?> getFromServer(String path) => _guard(() async {
    final data = await _access.readDocumentFromServer(path);
    return data == null ? null : StoredDocument(path, decodeFields(data));
  });

  @override
  Future<StoredDocument?> peek(String path) => _guard(() async {
    final data = await _access.peekDocument(path);
    return data == null ? null : StoredDocument(path, decodeFields(data));
  });

  @override
  Future<List<StoredDocument>> list(String collection) =>
      _guard(() async => _documents(await _access.readCollection(collection)));

  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) =>
      _guard(() async {
        final raw = switch (filter) {
          FieldEquals(:final field, :final value) => await _access.readQuery(
            collection,
            field,
            contains: false,
            value: _encode(value),
          ),
          FieldArrayContainsAny(:final field, :final values) =>
            await _access.readQuery(
              collection,
              field,
              contains: true,
              value: [for (final value in values) _encode(value)],
            ),
          AllEqual(:final clauses) => await _access.readQueryAll(collection, {
            for (final clause in clauses) clause.field: _encode(clause.value),
          }),
        };
        return _documents(raw);
      });

  @override
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => _guard(
    () async =>
        _documents(await _access.readGroup(collectionId, field, equalTo)),
  );

  @override
  Stream<DocumentUpdate> watchDocument(String path) =>
      _guardStream(_access.watchDocument(path), (event) {
        final data = event.data;
        return DocumentUpdate(
          data == null ? null : StoredDocument(path, decodeFields(data)),
          _snapshotMetadata(event.metadata),
        );
      });

  @override
  Stream<CollectionUpdate> watchCollection(String collection) =>
      _guardStream(_access.watchCollection(collection), _collectionUpdate);

  @override
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) =>
      _guardStream(switch (filter) {
        FieldEquals(:final field, :final value) => _access.watchQuery(
          collection,
          field,
          contains: false,
          value: _encode(value),
        ),
        FieldArrayContainsAny(:final field, :final values) =>
          _access.watchQuery(
            collection,
            field,
            contains: true,
            value: [for (final value in values) _encode(value)],
          ),
        AllEqual(:final clauses) => _access.watchQueryAll(collection, {
          for (final clause in clauses) clause.field: _encode(clause.value),
        }),
      }, _collectionUpdate);

  static CollectionUpdate _collectionUpdate(RawCollectionEvent event) =>
      CollectionUpdate(
        // Triés par identifiant, comme le serveur (le faux ne le garantit pas).
        _documents(event.documents)..sort((a, b) => a.path.compareTo(b.path)),
        _snapshotMetadata(event.metadata),
      );

  static UpdateMetadata _snapshotMetadata(RawMetadata metadata) =>
      UpdateMetadata(
        fromCache: metadata.fromCache,
        hasPendingWrites: metadata.hasPendingWrites,
      );

  /// Traduit un flux du SDK : valeurs en types simples, `FirebaseException`
  /// en [StoreFailure]. **Une erreur termine le flux** (l'écoute du SDK est
  /// déjà fermée côté serveur) ; annuler l'abonnement annule l'écoute du SDK.
  static Stream<R> _guardStream<E, R>(
    Stream<E> source,
    R Function(E) convert,
  ) => relayStream<E, R>(
    source,
    data: convert,
    error: (error) => error is FirebaseException
        ? StoreFailure(_code(error.code), '${error.code}: ${error.message}')
        : error,
  );

  @override
  Future<bool> createIfAbsent(String path, Fields fields) =>
      _guard(() => _access.createDocument(path, encodeFields(fields)));

  @override
  Future<void> commit(List<WriteOp> operations) => _guard(() {
    checkBatchSize(operations);
    return _access.writeBatch([
      for (final operation in operations)
        switch (operation) {
          SetOp(:final path, :final fields, :final merge) => (
            path: path,
            kind: merge ? RawWriteKind.setMerge : RawWriteKind.set,
            data: encodeFields(fields),
          ),
          UpdateOp(:final path, :final fields) => (
            path: path,
            kind: RawWriteKind.update,
            data: encodeFields(fields),
          ),
          DeleteOp(:final path) => (
            path: path,
            kind: RawWriteKind.delete,
            data: null,
          ),
        },
    ]);
  });

  static List<StoredDocument> _documents(List<RawDocument> raw) => [
    for (final document in raw)
      StoredDocument(document.path, decodeFields(document.data)),
  ];

  /// Les champs au format du SDK : `DateTime` en `Timestamp`, [serverTimestamp]
  /// en `FieldValue.serverTimestamp()`, [ArrayUnion] et [ArrayRemove] en leurs
  /// équivalents du SDK, listes et tables récursivement.
  static Map<String, Object?> encodeFields(Fields fields) => {
    for (final entry in fields.entries) entry.key: _encode(entry.value),
  };

  static Object? _encode(Object? value) => switch (value) {
    ServerTimestamp() => FieldValue.serverTimestamp(),
    ArrayUnion(:final values) => FieldValue.arrayUnion(_encodeAll(values)),
    ArrayRemove(:final values) => FieldValue.arrayRemove(_encodeAll(values)),
    final DateTime date => Timestamp.fromDate(date),
    final List<Object?> list => [for (final item in list) _encode(item)],
    final Map<String, Object?> map => encodeFields(map),
    _ => value,
  };

  static List<Object?> _encodeAll(List<Object?> values) => [
    for (final item in values) _encode(item),
  ];

  /// Les champs du SDK en valeurs simples : `Timestamp` en `DateTime`, listes
  /// et tables récursivement.
  static Fields decodeFields(Map<String, dynamic> data) => {
    for (final entry in data.entries) entry.key: _decode(entry.value),
  };

  static Object? _decode(Object? value) => switch (value) {
    final Timestamp timestamp => timestamp.toDate(),
    final List<Object?> list => [for (final item in list) _decode(item)],
    final Map<String, dynamic> map => decodeFields(map),
    _ => value,
  };

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (error) {
      throw StoreFailure(_code(error.code), '${error.code}: ${error.message}');
    }
  }

  static StoreFailureCode _code(String code) => switch (code) {
    'permission-denied' => StoreFailureCode.permissionDenied,
    'failed-precondition' => StoreFailureCode.failedPrecondition,
    'not-found' => StoreFailureCode.notFound,
    'unavailable' || 'deadline-exceeded' => StoreFailureCode.unavailable,
    _ => StoreFailureCode.other,
  };
}
