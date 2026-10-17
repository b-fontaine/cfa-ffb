import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Un document tel que le SDK le rend : son chemin et ses champs bruts
/// (`Timestamp` compris).
typedef RawDocument = ({String path, Map<String, dynamic> data});

/// Les quatre appels que `FirestoreDocumentStore` fait au SDK, sur des types
/// simples : de quoi tester tout le reste (traduction des valeurs et des
/// échecs) sans plugin ni réseau.
abstract interface class FirestoreAccess {
  Future<Map<String, dynamic>?> readDocument(String path);

  Future<List<RawDocument>> readCollection(String path);

  Future<List<RawDocument>> readGroup(
    String collectionId,
    String field,
    Object? equalTo,
  );

  /// Applique les écritures en **un seul lot** ; les champs sont déjà au
  /// format du SDK.
  Future<void> writeBatch(List<RawWrite> writes);
}

/// Une écriture déjà traduite : `set`, `update` (champs) ou `delete` (sans
/// champs).
typedef RawWrite = ({
  String path,
  RawWriteKind kind,
  Map<String, Object?>? data,
});

enum RawWriteKind { set, update, delete }

/// Les appels directs au SDK `cloud_firestore` : seul code de l'application qui
/// le touche (règle 9), volontairement minimal. N'est appelé qu'une fois
/// Firebase initialisé ; `FirebaseFirestore.instance` n'est lu qu'à l'appel.
/// Son comportement réel (règles, lot atomique, requête de groupe de
/// collections) est vérifié contre l'émulateur par `scripts/rules_test/`, qui
/// joue les mêmes opérations avec le SDK web.
class FirestoreSdkAccess implements FirestoreAccess {
  FirestoreSdkAccess({FirebaseFirestore Function()? firestore})
    : _firestore = firestore ?? (() => FirebaseFirestore.instance);

  final FirebaseFirestore Function() _firestore;

  @override
  Future<Map<String, dynamic>?> readDocument(String path) async {
    final snapshot = await _firestore().doc(path).get();
    return snapshot.exists ? snapshot.data() : null;
  }

  @override
  Future<List<RawDocument>> readCollection(String path) async =>
      _raw(await _firestore().collection(path).get());

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
  Future<void> writeBatch(List<RawWrite> writes) async {
    final firestore = _firestore();
    final batch = firestore.batch();
    for (final write in writes) {
      final reference = firestore.doc(write.path);
      switch (write.kind) {
        case RawWriteKind.set:
          batch.set(reference, write.data!);
        case RawWriteKind.update:
          batch.update(reference, write.data!);
        case RawWriteKind.delete:
          batch.delete(reference);
      }
    }
    await batch.commit();
  }

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
  Future<List<StoredDocument>> list(String collection) =>
      _guard(() async => _documents(await _access.readCollection(collection)));

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
  Future<void> commit(List<WriteOp> operations) => _guard(
    () => _access.writeBatch([
      for (final operation in operations)
        switch (operation) {
          SetOp(:final path, :final fields) => (
            path: path,
            kind: RawWriteKind.set,
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
    ]),
  );

  static List<StoredDocument> _documents(List<RawDocument> raw) => [
    for (final document in raw)
      StoredDocument(document.path, decodeFields(document.data)),
  ];

  /// Les champs au format du SDK : `DateTime` en `Timestamp`, [serverTimestamp]
  /// en `FieldValue.serverTimestamp()`, listes et tables récursivement.
  static Map<String, Object?> encodeFields(Fields fields) => {
    for (final entry in fields.entries) entry.key: _encode(entry.value),
  };

  static Object? _encode(Object? value) => switch (value) {
    ServerTimestamp() => FieldValue.serverTimestamp(),
    final DateTime date => Timestamp.fromDate(date),
    final List<Object?> list => [for (final item in list) _encode(item)],
    final Map<String, Object?> map => encodeFields(map),
    _ => value,
  };

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
    'not-found' => StoreFailureCode.notFound,
    'unavailable' || 'deadline-exceeded' => StoreFailureCode.unavailable,
    _ => StoreFailureCode.other,
  };
}
