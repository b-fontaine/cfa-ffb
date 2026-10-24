import 'package:billard_cfa/app/firestore_stale_marker_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_cubit.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/ui/stale_markers_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixed_clock.dart';
import 'in_memory_write_ledger.dart';

/// Un **faux serveur** devant le stock en mémoire, qui applique ce que les
/// règles Firestore imposent aux marqueurs pour le filet de 90 jours (FB8
/// partie B, B5 ; `scripts/rules_test/stale_markers.test.mjs` les joue pour
/// de vrai), à l'heure du **serveur** ([serverNow]) :
///
/// - **liste** : un gestionnaire du club (directeur du club, administrateur)
///   liste les imports sans condition (FB7) et les opérations par une requête
///   de plage `updatedAt < borne` dont la borne n'est pas plus récente que 90
///   jours ; l'auteur liste les siens (`createdBy == uid`) ; rien d'autre ;
/// - **suppression** : le sien (suffixe `_{uid}`), ou, pour un gestionnaire du
///   club, un marqueur dont `updatedAt` a plus de 90 jours ; un lot qui en
///   touche un autre est refusé **en bloc**.
///
/// Les 90 jours sont écrits ici à la main, comme dans `firestore.rules` : ce
/// faux ne fait pas confiance à la constante du domaine pour la prouver.
class StaleMarkerRulesStore implements DocumentStore {
  StaleMarkerRulesStore(this.inner, this.serverNow);

  final InMemoryDocumentStore inner;
  final DateTime Function() serverNow;

  /// L'âge du filet, recopié de `staleMarkerAge()` de `firestore.rules` ;
  /// sa parité est tenue par `test/unit/app/rules_parity_test.dart`.
  static const ruleAge = Duration(days: 90);

  String? authUid;
  Role? role;

  /// Réseau coupé : toute lecture et tout lot échouent (`unavailable`).
  bool offline = false;

  /// Collections de marqueurs listées, dans l'ordre.
  final List<String> listed = [];

  /// Taille de chaque lot appliqué.
  final List<int> batches = [];

  bool _manages(String club) =>
      role == Role.admin || (club == 'c1' && role == Role.director);

  bool _holds(String collection) =>
      role == Role.admin ||
      role == Role.director ||
      (role == Role.teacher && collection.endsWith('/imports'));

  static bool _isMarker(String collection) =>
      collection.endsWith('/imports') || collection.endsWith('/operations');

  static String _clubOf(String path) => path.split('/')[1];

  DateTime get _limit => serverNow().subtract(ruleAge);

  Never _deny(String why) =>
      throw StoreFailure(StoreFailureCode.permissionDenied, why);

  void _online() {
    if (offline) {
      throw const StoreFailure(StoreFailureCode.unavailable, 'hors ligne');
    }
  }

  @override
  Future<List<StoredDocument>> query(
    String collection,
    QueryFilter filter,
  ) async {
    _online();
    if (_isMarker(collection)) {
      listed.add(collection);
      final club = _clubOf(collection);
      final own =
          filter is FieldEquals &&
          filter.field == 'createdBy' &&
          filter.value == authUid &&
          club == 'c1' &&
          _holds(collection);
      final managerImports = collection.endsWith('/imports') && _manages(club);
      final staleOperations =
          collection.endsWith('/operations') &&
          _manages(club) &&
          filter is FieldBefore &&
          filter.field == 'updatedAt' &&
          !filter.value.isAfter(_limit);
      if (!own && !managerImports && !staleOperations) {
        _deny('liste de marqueurs refusée');
      }
    }
    return await inner.query(collection, filter);
  }

  @override
  Future<List<StoredDocument>> list(String collection) async {
    _online();
    if (_isMarker(collection)) {
      listed.add(collection);
      if (!(collection.endsWith('/imports') && _manages(_clubOf(collection)))) {
        _deny('liste sans filtre');
      }
    }
    return await inner.list(collection);
  }

  @override
  Future<void> commit(List<WriteOp> operations) async {
    _online();
    for (final operation in operations) {
      final segments = operation.path.split('/');
      final collection = segments.sublist(0, segments.length - 1).join('/');
      if (!_isMarker(collection)) continue;
      if (operation is! DeleteOp) _deny('seule la suppression est jouée ici');
      final mine =
          authUid != null &&
          operation.path.endsWith('_$authUid') &&
          _clubOf(collection) == 'c1' &&
          _holds(collection);
      final updatedAt = (await inner.peek(operation.path))?.fields['updatedAt'];
      final stale =
          _manages(_clubOf(collection)) &&
          updatedAt is DateTime &&
          updatedAt.isBefore(_limit);
      if (!mine && !stale) _deny('marqueur récent ou d’un autre club');
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

/// Un club `c1` où des marqueurs vieillissent, et la purge des marqueurs
/// abandonnés par-dessus : le vrai `FirestoreStaleMarkerStore`, le vrai cas
/// d'usage [PurgeStaleMarkers] et le vrai écran, derrière le faux serveur de
/// règles ; horloge figée commune à l'appareil et au serveur ; compte du jour
/// des écritures en mémoire (celui que partage l'import).
class StaleMarkersWorld {
  StaleMarkersWorld.open() {
    current = this;
    server.serverNow = clock.now;
  }

  static late StaleMarkersWorld current;

  static const club = ClubId('c1');

  /// Les comptes des scénarios : uid et rôle dans le club (« parti » : un
  /// compte supprimé, sans rôle).
  static const accounts = <String, ({String uid, Role? role})>{
    'parti': (uid: 'u-gone', role: null),
    'enseignant': (uid: 'u-teacher', role: Role.teacher),
    'directeur': (uid: 'u-dir', role: Role.director),
    'administrateur': (uid: 'u-admin', role: Role.admin),
  };

  final FixedClock clock = FixedClock(DateTime(2026, 10, 24, 10));
  final InMemoryDocumentStore server = InMemoryDocumentStore();
  late final StaleMarkerRulesStore rules = StaleMarkerRulesStore(
    server,
    clock.now,
  );
  late final InMemoryWriteLedger ledger = InMemoryWriteLedger(clock);

  /// L'issue de la dernière purge.
  StaleMarkerPurgeResult? result;

  var _next = 0;

  static ({String uid, Role? role}) account(String name) =>
      accounts[name] ?? (throw ArgumentError.value(name, 'name'));

  /// Une empreinte SHA-256 distincte à chaque appel (64 caractères hexa).
  String _key() => (_next++).toRadixString(16).padLeft(64, '0');

  /// [name] a laissé, dans [inClub], [imports] marqueurs d'import et
  /// [operations] marqueurs d'opération dont le dernier lot date de [daysAgo]
  /// jours (heure du serveur).
  void seed(
    String name, {
    required int imports,
    required int operations,
    required int daysAgo,
    String inClub = 'c1',
  }) {
    final uid = account(name).uid;
    final updatedAt = clock.now().subtract(Duration(days: daysAgo));
    for (var i = 0; i < imports; i++) {
      final key = _key();
      server.seed('clubs/$inClub/imports/${key}_$uid', {
        'fileId': key,
        'createdBy': uid,
        'state': i.isEven ? 'done' : 'running',
        'updatedAt': updatedAt,
      });
    }
    for (var i = 0; i < operations; i++) {
      final key = _key();
      server.seed('clubs/$inClub/operations/${key}_$uid', {
        'operationId': key,
        'createdBy': uid,
        'kind': i.isEven ? 'closure' : 'erasure',
        'updatedAt': updatedAt,
      });
    }
  }

  /// Retire tous les marqueurs de [name] dans `c1` (amorçage, sans règles).
  Future<void> clear(String name) async {
    final uid = account(name).uid;
    await server.commit([
      for (final path in server.documents.keys)
        if (path.startsWith('clubs/c1/') && path.endsWith('_$uid'))
          DeleteOp(path),
    ]);
  }

  /// La session de [name] dans `c1`, vue par le faux serveur.
  SessionScope _actAs(String name) {
    final (:uid, :role) = account(name);
    rules
      ..authUid = uid
      ..role = role;
    final scope = SessionScope()..signIn(UserId(uid));
    if (role != null) scope.activate(club, role);
    return scope;
  }

  PurgeStaleMarkers _useCase(SessionScope scope) =>
      PurgeStaleMarkers(FirestoreStaleMarkerStore(rules), ledger, clock, scope);

  /// Le compte [name] purge les marqueurs abandonnés du club.
  Future<void> purge(String name) async {
    result = await _useCase(_actAs(name))();
  }

  /// Ouvre la carte de « Mon club » pour le directeur (en français).
  Future<void> openCard(WidgetTester tester) async {
    final cubit = StaleMarkersCubit(_useCase(_actAs('directeur')).call);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider.value(
              value: cubit,
              child: const StaleMarkersSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Les marqueurs de [name] encore sur le serveur, dans [inClub].
  int markersOf(String name, {String inClub = 'c1'}) {
    final uid = account(name).uid;
    return server.documents.keys
        .where(
          (path) =>
              path.startsWith('clubs/$inClub/') &&
              (path.contains('/imports/') || path.contains('/operations/')) &&
              path.endsWith('_$uid'),
        )
        .length;
  }
}
