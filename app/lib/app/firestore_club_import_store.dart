import 'dart:async';

import 'package:billard_cfa/app/club_import_operations.dart';
import 'package:billard_cfa/app/import_marker_document.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Le club Firestore vu par l'import (FB7, ADR 0024 décision 19) : lecture de
/// son contenu **dans le périmètre du rôle**, écriture d'un lot atomique avec
/// le marqueur. Choisi par `DataBackendModule` avec `DataBackend.firestore` ;
/// avec drift, c'est `UnsupportedClubImportStore`.
///
/// - **Lecture** ([inventory]) : un gestionnaire liste les collections du
///   club ; un enseignant interroge **un groupe à la fois** (égalité sur
///   `groupId`) et ses fiches par `groupIds`, comme les dépôts : les règles ne
///   l'autorisent pas autrement. Rien de personnel n'en sort (identifiants et
///   dates). Coût : une lecture par document présent, **zéro pour un club
///   vide**.
/// - **Écriture** ([commit]) : `documents.commit` **attend l'accusé du
///   serveur** (jamais `ClubStore.commit`, qui rend la main avant) : le
///   marqueur n'avance que si le lot est accepté. Au-delà de [ackTimeout] sans
///   réponse (hors ligne), l'import est dit interrompu (`unavailable`) ;
///   l'écriture reste dans la file du SDK et sera envoyée à la reconnexion,
///   **au plus une fois** : le marqueur refuse un lot déjà appliqué.
/// - **Jamais d'écrasement** : un document présent à la lecture n'est pas
///   réécrit (sa fiche reçoit seulement les groupes manquants de `groupIds`).
///   L'inventaire peut être périmé (un document créé entre la lecture et le
///   lot) : la garantie vient donc **des règles**, pas de cette lecture. Chaque
///   création porte `importedAt` (date du serveur, voir `ClubImportOperations`)
///   que les règles refusent à toute mise à jour ; les passages et les saisies
///   le sont par leur `createdAt` figé. Une écriture d'import sur un document
///   présent est refusée **en bloc** avec le marqueur.
class FirestoreClubImportStore implements ClubImportStore {
  FirestoreClubImportStore(
    this._club,
    this._user, {
    this.ackTimeout = const Duration(seconds: 30),
  });

  /// `array-contains-any` accepte 30 valeurs au plus.
  static const _maxContainsAny = 30;

  final ClubStore _club;
  final CurrentUser _user;

  /// Combien de temps attendre l'accusé du serveur pour un lot.
  final Duration ackTimeout;

  // ───────────────────────── Lecture ─────────────────────────

  @override
  Future<ClubInventory> inventory(String fileId) => guardStore(() async {
    final paths = _club.paths;
    final role = _club.role;
    if (role != Role.director && role != Role.admin && role != Role.teacher) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'role');
    }
    final existing = <ImportCategory, Set<String>>{};
    Future<List<StoredDocument>> read(
      ImportCategory category,
      String collection,
    ) async {
      final documents = _club.manages
          ? await _club.documents.list(collection)
          : [
              for (final group in _club.groupIds)
                ...await _club.documents.query(
                  collection,
                  FieldEquals('groupId', group.value),
                ),
            ];
      existing[category] = {for (final document in documents) document.id};
      return documents;
    }

    final groupDocuments = _club.manages
        ? await _club.documents.list(paths.groups)
        : [
            for (final id in _club.groupIds)
              ?await _club.documents.get(paths.group(id)),
          ];
    existing[ImportCategory.groups] = {for (final d in groupDocuments) d.id};
    final seasonDocuments = await _club.documents.list(paths.seasons);
    existing[ImportCategory.seasons] = {for (final d in seasonDocuments) d.id};
    final studentDocuments = await _students(paths);
    existing[ImportCategory.students] = {
      for (final d in studentDocuments) d.id,
    };
    await read(ImportCategory.memberships, paths.memberships);
    existing[ImportCategory.seasonArchives] = {
      for (final d in await _club.documents.list(paths.archives)) d.id,
    };
    await read(ImportCategory.plannedSessions, paths.sessions);
    await read(ImportCategory.sessionRecords, paths.records);
    await read(ImportCategory.attempts, paths.attempts);
    await read(ImportCategory.acquisitions, paths.acquisitions);
    await read(ImportCategory.assessments, paths.assessments);
    await read(ImportCategory.acknowledgements, paths.acknowledgements);
    return ClubInventory(
      groups: _groups(groupDocuments),
      seasons: _seasons(seasonDocuments),
      students: {
        for (final d in studentDocuments)
          StudentId(d.id): {
            for (final id in DocumentValues(d.path, d.fields).list('groupIds'))
              if (id is String) GroupId(id),
          },
      },
      erasingStudents: {
        for (final d in studentDocuments)
          if (d.fields['erasing'] == true) StudentId(d.id),
      },
      existing: existing,
      marker: await _marker(fileId),
    );
  });

  Future<List<StoredDocument>> _students(ClubPaths paths) async {
    if (_club.manages) return await _club.documents.list(paths.students);
    final ids = [for (final group in _club.groupIds) group.value];
    final found = <String, StoredDocument>{};
    for (var i = 0; i < ids.length; i += _maxContainsAny) {
      final end = i + _maxContainsAny > ids.length
          ? ids.length
          : i + _maxContainsAny;
      for (final document in await _club.documents.query(
        paths.students,
        FieldArrayContainsAny('groupIds', ids.sublist(i, end)),
      )) {
        found[document.path] = document;
      }
    }
    return found.values.toList();
  }

  Map<GroupId, InventoryGroup> _groups(List<StoredDocument> documents) => {
    for (final d in documents)
      if (Audience.values.asNameMap()[d.fields['audience']]
          case final audience?)
        if (d.fields['seasonId'] case final String season)
          GroupId(d.id): InventoryGroup(SeasonId(season), audience),
  };

  Map<SeasonId, InventorySeason> _seasons(List<StoredDocument> documents) {
    final seasons = <SeasonId, InventorySeason>{};
    for (final document in documents) {
      final season = _inventorySeason(document);
      if (season != null) seasons[SeasonId(document.id)] = season;
    }
    return seasons;
  }

  /// Le marqueur **de ce compte** pour ce fichier, relu **au serveur** (jamais
  /// le cache : un cache en retard le ferait croire plus ou moins avancé
  /// qu'il n'est ; hors ligne, `unavailable`).
  Future<ImportMarker?> _marker(String fileId) async {
    final author = _user.id;
    if (author == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'user');
    }
    final document = await _club.documents.getFromServer(
      _club.paths.importMarker(fileId, author),
    );
    return document == null ? null : ImportMarkerDocument.decode(document);
  }

  @override
  Future<ImportMarker?> readMarker(String fileId) =>
      guardStore(() => _marker(fileId));

  // ───────────────────────── Écriture ─────────────────────────

  @override
  Future<void> commit(ImportLotCommit commit) => guardStore(() async {
    final paths = _club.paths;
    final author = _user.id;
    if (author == null) {
      throw const StoreFailure(StoreFailureCode.permissionDenied, 'user');
    }
    final operations = [
      for (final write in commit.lot.writes)
        ...ClubImportOperations.of(paths, write, commit.inventory, _user.id),
      if (commit.createsMarker)
        SetOp(
          paths.importMarker(commit.marker.fileId, author),
          ImportMarkerDocument.create(commit.marker, createdBy: author),
        )
      else
        UpdateOp(
          paths.importMarker(commit.marker.fileId, author),
          ImportMarkerDocument.advance(commit.marker),
        ),
    ];
    final send = Future.sync(() => _club.documents.commit(operations));
    try {
      await send.timeout(ackTimeout);
    } on TimeoutException {
      // L'écriture reste dans la file du SDK ; une erreur tardive ne doit pas
      // remonter comme non gérée.
      unawaited(send.then<void>((_) {}, onError: (Object _) {}));
      throw const StoreFailure(
        StoreFailureCode.unavailable,
        'lot sans réponse du serveur',
      );
    }
  });

  InventorySeason? _inventorySeason(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final start = values.optDate('startDate');
    final end = values.optDate('endDate');
    if (start == null || end == null) return null;
    return InventorySeason(
      startDate: start,
      endDate: end,
      closedOn: values.optDate('closedOn'),
    );
  }
}
