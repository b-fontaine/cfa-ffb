import 'package:billard_cfa/entities/session/data/session_document.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Séances planifiées du club actif dans `clubs/{c}/sessions/{id}`. Choisi par
/// `DataBackend.firestore`.
///
/// - Les règles lisent le groupe et la saison de chaque séance : **une séance
///   sans groupe n'existe pas** côté Firestore. La règle métier (le groupe est
///   obligatoire, décision du 2026-10-18) est dans `PlanSession` ; ce dépôt ne
///   garde qu'une garde défensive (`StoreFailure`, jamais affichée : une
///   séance sans groupe ne lui arrive que d'un import ou d'une migration, FB7).
///   La saison est celle du groupe, lue dans son document ;
/// - lecture : le directeur et l'administrateur listent le club ; un
///   enseignant, un parent ou un élève interrogent **un groupe à la fois**
///   (égalité sur `groupId`, que les règles vérifient) ;
/// - `delete` est physique (décision 15) ; la liste est triée par jour puis
///   identifiant.
class FirestoreSessionRepository implements SessionRepository {
  FirestoreSessionRepository(this._club);

  final ClubStore _club;

  @override
  Future<List<Session>> getAll() => guardStore(() async {
    final paths = _club.paths;
    final documents = _club.manages
        ? await _club.documents.list(paths.sessions)
        : await _ofGroups(_club.groupIds);
    final sessions = <Session>[
      for (final document in documents) SessionDocument.decode(document),
    ]..sort(SessionDocument.compare);
    return List.unmodifiable(sessions);
  });

  /// Suit [getAll] : le directeur et l'administrateur la collection ; les
  /// autres, une requête par groupe (égalité sur `groupId`).
  @override
  Stream<List<Session>> watchAll() => guardStoreStream(() {
    final sessions = _club.paths.sessions;
    return _club
        .watchSources([
          if (_club.manages)
            ReadSource.collection(sessions)
          else
            for (final group in _club.groupIds)
              ReadSource.query(sessions, FieldEquals('groupId', group.value)),
        ])
        .map((documents) {
          final sessions = <Session>[
            for (final document in documents) SessionDocument.decode(document),
          ]..sort(SessionDocument.compare);
          return List<Session>.unmodifiable(sessions);
        });
  });

  @override
  Future<void> add(Session session) => guardStore(() async {
    final group = session.groupId;
    if (group == null) {
      throw StoreFailure(
        StoreFailureCode.other,
        'session ${session.id}: no group',
      );
    }
    final paths = _club.paths;
    final groupDocument = await _club.get(paths.group(group));
    if (groupDocument == null) {
      // Le cas d'usage a déjà refusé un groupe inconnu (`unknownGroup`) : un
      // groupe absent ici est une incohérence du stock, pas une règle métier.
      throw StoreFailure(StoreFailureCode.notFound, paths.group(group));
    }
    final season = SeasonId(
      DocumentValues(
        groupDocument.path,
        groupDocument.fields,
      ).string('seasonId'),
    );
    final path = paths.session(session.id);
    final exists = await _club.get(path) != null;
    await _club.commit([
      SetOp(path, {
        ...SessionDocument.encode(session, season),
        if (!exists) ...SessionDocument.creationOnly(),
      }, merge: true),
    ]);
  });

  @override
  Future<void> delete(String id) =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.session(id))]));

  @override
  Future<Set<String>> idsOfGroups(Set<GroupId> groups) => guardStore(() async {
    final documents = await _ofGroups(groups);
    return {for (final document in documents) document.id};
  });

  Future<List<StoredDocument>> _ofGroups(Iterable<GroupId> groups) async => [
    for (final group in groups)
      ...await _club.documents.query(
        _club.paths.sessions,
        FieldEquals('groupId', group.value),
      ),
  ];
}
