import 'package:billard_cfa/entities/session_record/data/session_record_document.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Séances données du club actif dans `clubs/{c}/records/{id}`. Choisi par
/// `DataBackend.firestore`.
///
/// - **Identité** (ADR 0016 amendé, décision 18) : l'identifiant est choisi
///   par le cas d'usage (`sittingId` pour une saisie liée à une séance du
///   catalogue, UUID pour une saisie libre) ; `save` écrit **ce** document, par
///   fusion (champs facultatifs vidés, listes remplacées) ; `open` (ouverture
///   concurrente de la même saisie) réunit les présents par `ArrayUnion`,
///   `resume` (retour de l'animateur sur une saisie existante) les
///   **remplace** : décocher un élève coché par erreur reste possible ;
/// - **`createdAt`** : posé par la **création** seulement ; saisie liée : une
///   transaction `createIfAbsent` (jamais « lu absent puis écrit » : deux
///   appareils concurrents feraient une mise à jour qui change la date,
///   refusée par les règles) ; saisie libre : écriture simple, possible hors
///   ligne (voir `_create`) ;
/// - **lecture** : un parent ou un élève ne lit **aucune** saisie (règles) :
///   ces rôles reçoivent des listes vides. Le directeur et l'administrateur
///   interrogent le club ; un enseignant, **un groupe à la fois** (égalité sur
///   `groupId`, que les règles vérifient) ;
/// - `forStudent` : le gestionnaire interroge `presentStudentIds`
///   (`array-contains-any`) ; l'enseignant filtre ses groupes en mémoire (une
///   requête sans `groupId` serait refusée) ;
/// - `delete` est physique (décision 15) : les passages de la séance sont du
///   lot suivant (FB4, partie 3) ;
/// - `idsEverPresent` et `eraseStudent` (retrait par `ArrayRemove`) servent
///   l'effacement d'un élève, opération de gestionnaire : les suppressions
///   logiques n'existent plus, la liste ne contient que ce qui reste ;
/// - la liste est triée par jour puis identifiant.
class FirestoreSessionRecordRepository implements SessionRecordRepository {
  FirestoreSessionRecordRepository(this._club);

  final ClubStore _club;

  /// Remplacement : le document est **créé** (avec `createdAt`) s'il est
  /// absent, sinon fusionné **sans** `createdAt` (les règles figent la date
  /// d'une saisie : une écriture qui peut être une mise à jour ne l'envoie
  /// jamais).
  @override
  Future<void> save(SessionRecord session) => guardStore(() async {
    final path = _club.paths.record(session.id);
    final fields = SessionRecordDocument.encode(session);
    final created = await _create(session, path, fields);
    if (!created) await _club.commit([SetOp(path, fields, merge: true)]);
  });

  @override
  Future<SessionRecord> open(SessionRecord candidate) => guardStore(() async {
    final path = _club.paths.record(candidate.id);
    final created = await _create(
      candidate,
      path,
      SessionRecordDocument.encode(candidate),
    );
    if (!created) await _unionPresent(path, candidate);
    return await _stored(candidate);
  });

  @override
  Future<SessionRecord> resume(SessionRecord record) => guardStore(() async {
    final path = _club.paths.record(record.id);
    final created = await _create(
      record,
      path,
      SessionRecordDocument.encode(record),
    );
    if (!created) {
      await _club.commit([
        UpdateOp(path, SessionRecordDocument.encodeResumed(record)),
      ]);
    }
    return await _stored(record);
  });

  /// Crée [record] avec sa date de création, `false` s'il existe déjà.
  ///
  /// - saisie **liée** à une séance du catalogue (identifiant déterministe,
  ///   deux appareils peuvent la créer ensemble) : transaction
  ///   `createIfAbsent`, atomique côté serveur, donc **impossible hors ligne**
  ///   (limite connue, reste de FB5b : voir hors-ligne-plan.md) ;
  /// - saisie **libre** (identifiant UUID : aucun autre appareil ne peut la
  ///   créer en même temps) : création **par écriture simple** si le cache
  ///   local ne connaît pas le document, **possible hors ligne**. Si le
  ///   document existait pourtant sur le serveur sans être au cache, c'est une
  ///   mise à jour qui change `createdAt` : les règles la refusent et le refus
  ///   remonte par `SendStatus.hasFailure` (détail :
  ///   `SendTracker.lastFailure`).
  Future<bool> _create(SessionRecord record, String path, Fields fields) async {
    final creation = {...fields, ...SessionRecordDocument.creationOnly()};
    if (record.sheetId != null) {
      return await _club.createIfAbsent(path, creation);
    }
    if (await _club.peek(path) != null) return false;
    await _club.commit([SetOp(path, creation, merge: true)]);
    return true;
  }

  /// Réunit les présents de [candidate] à ceux du document, côté serveur
  /// (`ArrayUnion`) : la liste n'est ni lue ni réécrite. Les règles refusent
  /// une liste de plus de [maxPresentStudents] sans dire pourquoi : après un
  /// refus, la saisie est relue et, si la réunion dépasse la borne, l'échec
  /// est dit en termes du domaine ([InvariantCode.tooManyPresent]).
  Future<void> _unionPresent(String path, SessionRecord candidate) async {
    if (candidate.present.isEmpty) return;
    try {
      await _club.commit([
        UpdateOp(path, {
          'presentStudentIds': ArrayUnion(
            SessionRecordDocument.encodePresent(candidate.present),
          ),
        }),
      ]);
    } on StoreFailure catch (failure) {
      if (failure.code != StoreFailureCode.permissionDenied) rethrow;
      final stored = await _club.get(path);
      if (stored != null) {
        final union = {
          ...SessionRecordDocument.presentOf(stored),
          ...SessionRecordDocument.encodePresent(candidate.present),
        };
        if (union.length > maxPresentStudents) {
          throw const InvariantViolation(InvariantCode.tooManyPresent);
        }
      }
      rethrow;
    }
  }

  Future<SessionRecord> _stored(SessionRecord fallback) async {
    final document = await _club.cachedOrGet(_club.paths.record(fallback.id));
    return document == null ? fallback : SessionRecordDocument.decode(document);
  }

  @override
  Future<SessionRecord?> byId(SessionId id) => guardStore(() async {
    final document = await _club.get(_club.paths.record(id));
    return document == null ? null : SessionRecordDocument.decode(document);
  });

  @override
  Future<List<SessionRecord>> forGroup(GroupId groupId) =>
      guardStore(() async => _sorted(await _ofGroups([groupId])));

  @override
  Future<List<SessionRecord>> forStudent(StudentId studentId) =>
      guardStore(() async => _sorted(await _presentDocuments(studentId)));

  @override
  Future<Set<SessionId>> idsEverPresent(StudentId studentId) =>
      guardStore(() async {
        final documents = await _presentDocuments(studentId);
        return {for (final document in documents) SessionId(document.id)};
      });

  @override
  Future<List<SessionRecord>> all() => guardStore(() async {
    if (!_readable) return const [];
    final documents = _club.manages
        ? await _club.documents.list(_club.paths.records)
        : await _ofGroups(_club.groupIds);
    return _sorted(documents);
  });

  @override
  Future<void> setTags(SessionId id, Set<SessionTag> tags) =>
      guardStore(() async {
        final path = _club.paths.record(id);
        if (await _club.get(path) == null) return;
        await _club.commit([
          UpdateOp(path, {'tags': SessionRecordDocument.encodeTags(tags)}),
        ]);
      });

  @override
  Future<void> delete(SessionId id) =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.record(id))]));

  @override
  Future<void> eraseStudent(StudentId studentId) => guardStore(() async {
    final documents = await _club.documents.query(
      _club.paths.records,
      FieldArrayContainsAny('presentStudentIds', [studentId.value]),
    );
    await _club.commit([
      for (final document in documents)
        UpdateOp(document.path, {
          'presentStudentIds': ArrayRemove([studentId.value]),
        }),
    ]);
  });

  /// Les règles lisent les saisies aux animateurs seulement.
  bool get _readable =>
      _club.role != Role.student && _club.role != Role.guardian;

  Future<List<StoredDocument>> _ofGroups(Iterable<GroupId> groups) async {
    if (!_readable) return const [];
    return [
      for (final group in groups)
        ...await _club.documents.query(
          _club.paths.records,
          FieldEquals('groupId', group.value),
        ),
    ];
  }

  Future<List<StoredDocument>> _presentDocuments(StudentId student) async {
    if (!_readable) return const [];
    if (_club.manages) {
      return await _club.documents.query(
        _club.paths.records,
        FieldArrayContainsAny('presentStudentIds', [student.value]),
      );
    }
    return [
      for (final document in await _ofGroups(_club.groupIds))
        if (SessionRecordDocument.presentOf(document).contains(student.value))
          document,
    ];
  }

  List<SessionRecord> _sorted(List<StoredDocument> documents) =>
      [for (final document in documents) SessionRecordDocument.decode(document)]
        ..sort(SessionRecordDocument.compare);
}
