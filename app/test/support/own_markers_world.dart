import 'package:billard_cfa/app/firestore_own_marker_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/remove_own_markers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';

/// Un **faux serveur** devant le stock en mémoire, qui applique ce que les
/// règles Firestore imposent aux marqueurs d'import et d'opération (FB8
/// partie B, B1 ; `scripts/rules_test/matrix.test.mjs` et `import.test.mjs`
/// les jouent pour de vrai) :
///
/// - **liste** des marqueurs : seulement par un rôle qui en pose (import :
///   enseignant, directeur, administrateur ; opération : directeur,
///   administrateur), et filtrée sur `createdBy == uid` (sauf la liste des
///   imports par un gestionnaire) ;
/// - **suppression** : celle de son marqueur seul (identifiant suffixé par
///   son uid), par un rôle qui en pose ; un lot qui touche celui d'un autre est
///   refusé en bloc.
///
/// Il simule la coupure du réseau après [failAfterBatches] lots, et compte
/// les listes demandées et les lots envoyés.
class MarkerRulesStore implements DocumentStore {
  MarkerRulesStore(this.inner);

  final InMemoryDocumentStore inner;

  String? authUid;
  Role? role;

  /// Collections de marqueurs listées (dans l'ordre).
  final List<String> listed = [];

  /// Taille de chaque lot appliqué.
  final List<int> batches = [];

  /// Après ce nombre de lots appliqués, le lot suivant échoue
  /// (`unavailable`) sans être appliqué.
  int? failAfterBatches;

  bool get _manages => role == Role.director || role == Role.admin;

  bool _holds(String collection) => collection.endsWith('/imports')
      ? _manages || role == Role.teacher
      : collection.endsWith('/operations') && _manages;

  Never _deny(String why) =>
      throw StoreFailure(StoreFailureCode.permissionDenied, why);

  bool _isMarker(String collection) =>
      collection.endsWith('/imports') || collection.endsWith('/operations');

  @override
  Future<List<StoredDocument>> query(
    String collection,
    QueryFilter filter,
  ) async {
    if (_isMarker(collection)) {
      listed.add(collection);
      if (!_holds(collection)) _deny('rôle sans marqueur');
      final own =
          filter is FieldEquals &&
          filter.field == 'createdBy' &&
          filter.value == authUid;
      final managerImports = collection.endsWith('/imports') && _manages;
      if (!own && !managerImports) _deny('liste sans filtre sur l’auteur');
    }
    return await inner.query(collection, filter);
  }

  @override
  Future<List<StoredDocument>> list(String collection) async {
    if (_isMarker(collection)) {
      listed.add(collection);
      if (!(collection.endsWith('/imports') && _manages)) {
        _deny('liste sans filtre sur l’auteur');
      }
    }
    return await inner.list(collection);
  }

  @override
  Future<void> commit(List<WriteOp> operations) async {
    final failAfter = failAfterBatches;
    if (failAfter != null && batches.length >= failAfter) {
      throw const StoreFailure(StoreFailureCode.unavailable, 'coupure');
    }
    for (final operation in operations) {
      final segments = operation.path.split('/');
      final collection = segments.sublist(0, segments.length - 1).join('/');
      if (!_isMarker(collection)) continue;
      if (operation is! DeleteOp) _deny('seule la suppression est jouée ici');
      if (!_holds(collection)) _deny('rôle sans marqueur');
      if (authUid == null || !operation.path.endsWith('_$authUid')) {
        _deny('marqueur d’un autre auteur');
      }
    }
    await inner.commit(operations);
    batches.add(operations.length);
  }

  @override
  Future<StoredDocument?> get(String path) => inner.get(path);

  @override
  Future<StoredDocument?> peek(String path) => inner.peek(path);

  @override
  Future<StoredDocument?> getFromServer(String path) =>
      inner.getFromServer(path);

  /// Sans cache dans ce double : la lecture au serveur est [query].
  @override
  Future<List<StoredDocument>> queryFromServer(
    String collection,
    QueryFilter filter,
  ) => query(collection, filter);

  /// Sans cache dans ce double : la lecture au serveur est [collectionGroup].
  @override
  Future<List<StoredDocument>> collectionGroupFromServer(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => collectionGroup(collectionId, field: field, equalTo: equalTo);

  @override
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => inner.collectionGroup(collectionId, field: field, equalTo: equalTo);

  @override
  Stream<DocumentUpdate> watchDocument(String path) =>
      inner.watchDocument(path);

  @override
  Stream<CollectionUpdate> watchCollection(String collection) =>
      inner.watchCollection(collection);

  @override
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) =>
      inner.watchQuery(collection, filter);

  @override
  Future<bool> createIfAbsent(String path, Fields fields) =>
      inner.createIfAbsent(path, fields);
}

/// Un club `c1` où des comptes ont laissé des marqueurs, et le nettoyage par
/// leur auteur par-dessus : le vrai `FirestoreOwnMarkerStore` et le vrai cas
/// d'usage [RemoveOwnMarkers], derrière le faux serveur de règles.
class OwnMarkersWorld {
  OwnMarkersWorld.open() {
    current = this;
  }

  static late OwnMarkersWorld current;

  static const club = ClubId('c1');

  /// Les comptes des scénarios : uid et rôle dans le club.
  static const accounts = <String, ({String uid, Role role})>{
    'directeur': (uid: 'u-dir', role: Role.director),
    'enseignant': (uid: 'u-teacher', role: Role.teacher),
    'administrateur': (uid: 'u-admin', role: Role.admin),
    'parent': (uid: 'u-guardian', role: Role.guardian),
  };

  final InMemoryDocumentStore server = InMemoryDocumentStore();
  late final MarkerRulesStore rules = MarkerRulesStore(server);

  /// Le nombre de marqueurs retirés par le dernier nettoyage, ou son échec.
  int? removed;
  ServiceFailure? failure;

  var _next = 0;

  static ({String uid, Role role}) account(String name) =>
      accounts[name] ?? (throw ArgumentError.value(name, 'name'));

  /// Une empreinte SHA-256 distincte à chaque appel (64 caractères hexa).
  String _key() => (_next++).toRadixString(16).padLeft(64, '0');

  /// [name] a laissé [imports] marqueurs d'import et [operations] marqueurs
  /// d'opération (en plus de ceux qu'il avait).
  void seed(String name, {required int imports, required int operations}) {
    final uid = account(name).uid;
    for (var i = 0; i < imports; i++) {
      final key = _key();
      server.seed('clubs/c1/imports/${key}_$uid', {
        'fileId': key,
        'createdBy': uid,
        'state': i.isEven ? 'done' : 'running',
      });
    }
    for (var i = 0; i < operations; i++) {
      final key = _key();
      server.seed('clubs/c1/operations/${key}_$uid', {
        'operationId': key,
        'createdBy': uid,
        'kind': i.isEven ? 'closure' : 'erasure',
      });
    }
  }

  /// Le compte [name] retire ses marqueurs du club.
  Future<void> removeOwn(String name) async {
    final (:uid, :role) = account(name);
    rules
      ..authUid = uid
      ..role = role;
    final scope = SessionScope()..signIn(UserId(uid));
    removed = null;
    failure = null;
    try {
      removed = await RemoveOwnMarkers(FirestoreOwnMarkerStore(rules, scope))
          .call(club, role);
    } on ServiceFailure catch (caught) {
      failure = caught;
    }
  }

  /// Les marqueurs (import et opération) de [name] encore sur le serveur.
  int markersOf(String name) {
    final uid = account(name).uid;
    return server.documents.keys
        .where(
          (path) =>
              (path.contains('/imports/') || path.contains('/operations/')) &&
              path.endsWith('_$uid'),
        )
        .length;
  }
}
