import 'dart:async';

import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/combine_latest.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes.dart';
import 'package:billard_cfa/shared/persistence/relay_stream.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:injectable/injectable.dart';

/// Le [DocumentStore] vu depuis le club actif : les dépôts Firestore y
/// résolvent **à chaque appel** le club de la session ([ActiveClubScope]), pas
/// à la construction. Un dépôt unique survit ainsi à un changement de club, et
/// aucun appel ne peut écrire dans le club précédent : la résolution est
/// relue avant chaque lecture ou écriture.
@LazySingleton()
final class ClubStore {
  const ClubStore(
    this.documents,
    this._scope, {
    this._sends,
    this._network,
    @ignoreParam this.ackGrace = const Duration(milliseconds: 1500),
  });

  final DocumentStore documents;
  final ActiveClubScope _scope;

  /// Le suivi des envois : quand il est là, une écriture **hors unité de
  /// travail** n'attend plus l'accusé du serveur au-delà de [ackGrace] (voir
  /// [commit]) ; sans lui (tests unitaires des dépôts), elle l'attend.
  final SendTracker? _sends;

  /// Ce que l'on sait du réseau (indice : seul le web le connaît).
  final ConnectivityStatus? _network;

  /// Combien de temps une écriture attend l'accusé du serveur avant d'être
  /// confiée au suivi des envois. Le SDK l'applique au cache local dès
  /// l'appel :
  /// l'interface n'a aucune raison d'attendre le réseau plus longtemps qu'une
  /// réponse normale.
  final Duration ackGrace;

  /// Rôle courant dans le club actif (`null` sans club).
  Role? get role => _scope.role;

  /// Groupes du périmètre du membre (enseignant, parent, élève).
  List<GroupId> get groupIds => _scope.groupIds;

  /// Fiches du périmètre du membre (parent, élève).
  List<StudentId> get studentIds => _scope.studentIds;

  /// Directeur ou administrateur : voit tout le club.
  bool get manages => _scope.role == Role.director || _scope.role == Role.admin;

  /// Chemins du club actif. Sans club actif, l'accès est refusé (jamais un
  /// chemin construit au hasard) : [ServiceFailure] `denied`.
  ClubPaths get paths {
    final club = _scope.clubId;
    if (club == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'no-active-club');
    }
    return ClubPaths(club);
  }

  /// Les écritures en attente de l'unité de travail en cours (même zone),
  /// `null` hors unité.
  PendingWrites? get _pending => Zone.current[_unitKey] as PendingWrites?;

  /// Lit [path] ; dans une unité de travail, avec **ses propres écritures**
  /// (un dépôt relit ce qu'il vient d'écrire dans la même unité).
  Future<StoredDocument?> get(String path) async {
    final stored = await documents.get(path);
    final pending = _pending;
    if (pending == null) return stored;
    final fields = pending.overlay(path, stored?.fields);
    return fields == null ? null : StoredDocument(path, fields);
  }

  /// Comme [get], mais **depuis le cache local seulement** (voir
  /// `DocumentStore.peek`) : sans attente du réseau, `null` si le document
  /// n'y est pas. Dans une unité de travail, avec ses propres écritures.
  Future<StoredDocument?> peek(String path) async {
    final stored = await documents.peek(path);
    final pending = _pending;
    if (pending == null) return stored;
    final fields = pending.overlay(path, stored?.fields);
    return fields == null ? null : StoredDocument(path, fields);
  }

  /// Lit [path] dans le cache local, et à défaut seulement sur le serveur : la
  /// lecture des documents qui **permettent d'écrire** (fiche, groupe, séance :
  /// le propriétaire d'une donnée), rapide et possible hors ligne quand
  /// l'animateur les a sous les yeux.
  Future<StoredDocument?> cachedOrGet(String path) async =>
      await peek(path) ?? await get(path);

  /// Suit [path] (voir `DocumentStore.watchDocument`), **attaché à la portée
  /// courante** : voir [_pinned].
  Stream<DocumentUpdate> watchDocument(String path) =>
      _pinned(documents.watchDocument(path));

  /// Suit [collection], attaché à la portée courante.
  Stream<CollectionUpdate> watchCollection(String collection) =>
      _pinned(documents.watchCollection(collection));

  /// Suit les documents de [collection] qui satisfont [filter], attaché à la
  /// portée courante.
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) =>
      _pinned(documents.watchQuery(collection, filter));

  /// Suit l'union des [sources] : tous leurs documents, à chaque changement de
  /// l'une d'elles, **un seul état** à la fois (jamais une source à jour et
  /// l'autre non). Les lectures d'un enseignant (une requête par groupe), d'un
  /// parent (une par fiche liée) ou d'un gestionnaire (la collection) se
  /// décrivent par des sources ; une erreur d'une source (règle qui refuse)
  /// termine l'ensemble et libère toutes les écoutes. Attaché à la portée
  /// courante.
  Stream<List<StoredDocument>> watchSources(List<ReadSource> sources) =>
      _pinned(
        combineLatest<List<StoredDocument>>([
          for (final source in sources)
            if (source.document case final path?)
              documents.watchDocument(path).map((update) => [?update.document])
            else
              switch (source.filter) {
                null => documents.watchCollection(source.collection),
                final filter => documents.watchQuery(source.collection, filter),
              }.map((update) => update.documents),
        ]).map((lists) => [for (final list in lists) ...list]),
      );

  /// Un flux **lié à la portée** (club, rôle, groupes et fiches) dans laquelle
  /// il a été ouvert : si la session change (autre club, autre rôle, autre
  /// périmètre, déconnexion), le flux livre une erreur `permissionDenied` et
  /// se ferme, **en relâchant l'écoute**, au lieu de servir des documents d'un
  /// périmètre que le membre n'a plus. La fermeture a lieu **à l'écriture de
  /// la portée** (`ActiveClubScope.changes`), sans attendre un événement du
  /// serveur ; un événement qui arriverait quand même est aussi refusé. Les
  /// blocs abonnés ne sont pas refermés par la bascule (les pages ouvertes
  /// gardent les leurs) : c'est cette erreur qui les en avertit, et
  /// `LiveReload` rouvre alors l'écoute sous la nouvelle portée.
  Stream<T> _pinned<T>(Stream<T> source) {
    final pinned = _scopeKey();
    return relayStream<T, T>(
      source,
      data: (event) => event,
      valid: () => _scopeKey() == pinned,
      invalid: () => const StoreFailure(
        StoreFailureCode.permissionDenied,
        'scope-changed',
      ),
      recheck: _scope.changes,
    );
  }

  String _scopeKey() => scopeKeyOf(
    club: _scope.clubId,
    role: _scope.role,
    groups: _scope.groupIds,
    students: _scope.studentIds,
  );

  /// Vrai quand une réponse du serveur est à attendre : le réseau n'est pas
  /// connu coupé et aucun envoi n'attend déjà (les accusés arrivent dans
  /// l'ordre : derrière un envoi en attente, le suivant ne sera pas acquitté
  /// plus tôt). C'est ce qui décide d'**essayer** une transaction ou d'écrire
  /// sans attendre le serveur.
  bool get mayAwaitServer {
    final sends = _sends;
    if (sends == null) return true;
    return (_network?.online ?? true) && sends.pending == 0;
  }

  /// Écrit [operations]. Dans une unité de travail ([atomically]), elles
  /// attendent le lot unique de sa fin. Hors unité, elles partent par lots de
  /// [maxBatchWrites] : un lot est atomique ; au-delà, les lots se suivent et
  /// une coupure laisse un état partiel : les écritures des dépôts sont
  /// **idempotentes** (mêmes identifiants), la reprise rejoue l'ensemble (ADR
  /// 0024, décision 19).
  ///
  /// **Jamais bloquant hors ligne** (FB5b) : le SDK applique le lot au cache
  /// local dès l'appel, mais n'achève son `Future` qu'à l'accusé du serveur,
  /// donc jamais tant que l'appareil est hors ligne. Avec un suivi des envois,
  /// l'écriture attend l'accusé au plus [ackGrace] (et pas du tout si le
  /// réseau est connu coupé ou si un envoi attend déjà), puis le confie au
  /// suivi (`SendTracker.track`) : la pastille dit l'envoi en attente, et un
  /// refus tardif des règles (qui annule l'écriture sur l'appareil) arrive à
  /// la pastille, pas à l'appelant. Un refus **dans le délai** reste l'échec de
  /// l'appelant.
  ///
  /// [ifRefused] (un seul lot) : si le serveur **refuse** le lot
  /// (`permission-denied`), cette écriture de remplacement est envoyée, et le
  /// refus n'est pas signalé ; c'est la reprise d'une création faite sans
  /// transaction (voir `FirestoreSessionRecordRepository`). Un échec de la
  /// reprise est signalé comme tout échec d'envoi.
  Future<void> commit(
    List<WriteOp> operations, {
    Future<void> Function()? ifRefused,
  }) async {
    final pending = _pending;
    if (pending != null) {
      operations.forEach(pending.add);
      return;
    }
    assert(
      ifRefused == null || operations.length <= maxBatchWrites,
      'ifRefused : un seul lot',
    );
    for (var i = 0; i < operations.length; i += maxBatchWrites) {
      final end = i + maxBatchWrites;
      await _send(
        operations.sublist(
          i,
          end > operations.length ? operations.length : end,
        ),
        ifRefused,
      );
    }
  }

  Future<void> _send(
    List<WriteOp> batch,
    Future<void> Function()? ifRefused,
  ) async {
    // `Future.sync` : un échec levé à l'appel d'un stock est un échec du lot
    // comme un autre (le SDK, lui, le livre par le `Future`).
    var send = Future.sync(() => documents.commit(batch));
    if (ifRefused != null) {
      send = send.catchError((Object error, StackTrace stack) async {
        if (error is StoreFailure &&
            error.code == StoreFailureCode.permissionDenied) {
          return await ifRefused();
        }
        Error.throwWithStackTrace(error, stack);
      });
    }
    final sends = _sends;
    if (sends == null) return await send;
    if (!mayAwaitServer) {
      sends.track(send);
      return;
    }
    try {
      await send.timeout(ackGrace);
    } on TimeoutException {
      sends.track(send);
    }
  }

  /// Crée [path] s'il est absent (atomique côté serveur, voir
  /// `DocumentStore.createIfAbsent`) ; `false` s'il existe déjà. Réservé aux
  /// écritures **hors** unité de travail : une création conditionnelle ne peut
  /// pas attendre le lot de la fin : dans une unité, `StoreFailure`
  /// `unsupported` (donc `ServiceFailure` `unsupported` sorti d'un dépôt),
  /// jamais une exception hors `Failure`. C'est ce qui rend l'import d'une
  /// sauvegarde
  /// explicitement non supporté avec Firestore avant FB7.
  Future<bool> createIfAbsent(String path, Fields fields) async {
    if (_pending != null) {
      throw const StoreFailure(
        StoreFailureCode.unsupported,
        'createIfAbsent hors unité de travail seulement',
      );
    }
    final creation = documents.createIfAbsent(path, fields);
    if (_sends == null) return await creation;
    // Une transaction ne se fait pas hors ligne : le SDK la retente et finit
    // par
    // échouer, bien après ce qu'un écran peut attendre. Passé [ackGrace], le
    // serveur est dit injoignable (la transaction, si elle aboutit quand même,
    // est rattrapée par la reprise de l'appelant).
    return await creation.timeout(
      ackGrace,
      onTimeout: () => throw const StoreFailure(
        StoreFailureCode.unavailable,
        'transaction sans réponse',
      ),
    );
  }

  /// Exécute [body] ; toutes les écritures qu'il demande à [commit] partent
  /// en **un seul lot atomique** à sa fin (au plus [maxBatchWrites], sinon
  /// `StoreFailure(batchTooLarge)` sans rien écrire), ou aucune si [body]
  /// échoue. Une unité imbriquée rejoint l'unité englobante.
  ///
  /// Avec [onSend], le lot est **envoyé sans être attendu** : le SDK l'applique
  /// au cache local dès l'appel, l'accusé du serveur (jamais, hors ligne) est
  /// confié à [onSend] (`SendTracker.track`), pas à l'appelant : une
  /// transaction locale qui enveloppe l'unité ne reste pas ouverte.
  Future<T> atomically<T>(
    Future<T> Function() body, {
    void Function(Future<void> send)? onSend,
  }) async {
    if (_pending != null) return await body();
    final pending = PendingWrites();
    final result = await runZoned(body, zoneValues: {_unitKey: pending});
    final operations = pending.operations;
    if (operations.isEmpty) return result;
    // Taille vérifiée AVANT l'envoi : un envoi non attendu ne peut plus la
    // refuser à l'appelant.
    checkBatchSize(operations);
    final send = documents.commit(operations);
    if (onSend == null) {
      await send;
    } else {
      onSend(send);
    }
    return result;
  }
}

/// Une lecture : toute une collection, une requête (un champ, un opérateur :
/// jamais d'index composite) ou un seul document.
final class ReadSource {
  /// Toute la [collection].
  const ReadSource.collection(this.collection) : filter = null, document = null;

  /// Les documents de [collection] qui satisfont [filter].
  const ReadSource.query(this.collection, QueryFilter this.filter)
    : document = null;

  /// Le seul document `path` (aucun document s'il n'existe pas).
  const ReadSource.document(String this.document)
    : collection = '',
      filter = null;

  final String collection;
  final QueryFilter? filter;
  final String? document;
}

/// Clé de zone de l'unité de travail en cours.
final Object _unitKey = Object();
