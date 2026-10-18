import 'package:billard_cfa/entities/exercise_result/data/attempt_document.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Passages du club actif dans `clubs/{c}/attempts/{id}`, **un document par
/// passage** (ADR 0024, décision 17, qui amende l'ADR 0006). Choisi par
/// `DataBackend.firestore`.
///
/// - **Ajout seul** : `add` crée le document (jamais de lecture avant : hors
///   ligne, un `get` d'un document absent échouerait) avec `createdAt` du
///   serveur, que les règles exigent à la création et interdisent ensuite ;
///   rejouer un identifiant connu est donc **refusé** (`denied`). La
///   **correction** (`correct`) ne réécrit que `potted` et `total` ;
/// - **rang dérivé** : rien n'est stocké ni renuméroté ; les lectures rendent
///   l'ordre d'enregistrement (`createdAt`, `recordedAt`, identifiant), et la
///   suppression d'un passage ne réécrit aucun autre document ;
/// - **groupe et saison** dénormalisés : ceux de la séance du passage, lus dans
///   son document (`OwnerResolver.ofSession`) ;
/// - **lecture par rôle** (les règles ne filtrent pas les champs) : le
///   directeur et l'administrateur interrogent le club ; un enseignant, **un
///   groupe à la fois** (égalité sur `groupId`, avec l'élève ou la séance) ;
///   un parent ou un élève, **la fiche liée** seulement (égalité sur
///   `studentId`, que les règles vérifient) ;
/// - `delete` est physique (décision 15) ; `eraseStudent` est réservé aux
///   gestionnaires (requête par élève).
class FirestoreAttemptRepository implements AttemptRepository {
  FirestoreAttemptRepository(this._club, {Clock? clock})
    : _owners = OwnerResolver(_club),
      _clock = clock ?? SystemClock();

  final ClubStore _club;
  final OwnerResolver _owners;
  final Clock _clock;
  DateTime? _lastRecordedAt;

  /// L'horloge de l'appareil, **strictement croissante** (une horloge à la
  /// milliseconde, ou reculée, ne confond jamais deux saisies rapprochées).
  DateTime _nextRecordedAt() {
    final now = _clock.now().toUtc();
    final last = _lastRecordedAt;
    final next = last != null && !now.isAfter(last)
        ? last.add(const Duration(microseconds: 1))
        : now;
    return _lastRecordedAt = next;
  }

  @override
  Future<void> add(ExerciseAttempt attempt) => guardStore(() async {
    final owner = await _owners.ofSession(attempt.sessionId);
    await _club.commit([
      SetOp(
        _club.paths.attempt(attempt.id),
        AttemptDocument.encode(attempt, owner, recordedAt: _nextRecordedAt()),
      ),
    ]);
  });

  @override
  Future<void> correct(ExerciseAttempt attempt) => guardStore(() async {
    final path = _club.paths.attempt(attempt.id);
    if (await _club.get(path) == null) {
      throw NotFound('attempt', attempt.id.value);
    }
    await _club.commit([UpdateOp(path, AttemptDocument.correction(attempt))]);
  });

  @override
  Future<List<ExerciseAttempt>> forStudent(StudentId studentId) =>
      guardStore(() async {
        final documents = _club.manages
            ? await _club.documents.query(
                _club.paths.attempts,
                FieldEquals('studentId', studentId.value),
              )
            : _club.role == Role.teacher
            ? await _ofGroups(
                (group) => AllEqual([
                  FieldEquals('groupId', group.value),
                  FieldEquals('studentId', studentId.value),
                ]),
              )
            : await _ofLinked([studentId]);
        return _ordered(documents);
      });

  @override
  Future<List<ExerciseAttempt>> forSession(SessionId sessionId) =>
      guardStore(() async {
        final documents = _club.manages
            ? await _club.documents.query(
                _club.paths.attempts,
                FieldEquals('sessionId', sessionId.value),
              )
            : _club.role == Role.teacher
            ? await _ofGroups(
                (group) => AllEqual([
                  FieldEquals('groupId', group.value),
                  FieldEquals('sessionId', sessionId.value),
                ]),
              )
            : await _ofLinked(
                _club.studentIds,
                (student) => AllEqual([
                  FieldEquals('studentId', student.value),
                  FieldEquals('sessionId', sessionId.value),
                ]),
              );
        return _ordered(documents);
      });

  @override
  Future<List<ExerciseAttempt>> all() => guardStore(() async {
    final documents = _club.manages
        ? await _club.documents.list(_club.paths.attempts)
        : _club.role == Role.teacher
        ? await _ofGroups((group) => FieldEquals('groupId', group.value))
        : await _ofLinked(_club.studentIds);
    return _ordered(documents);
  });

  @override
  Future<void> delete(AttemptId id) =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.attempt(id))]));

  @override
  Future<void> eraseStudent(StudentId studentId) => guardStore(() async {
    final documents = await _club.documents.query(
      _club.paths.attempts,
      FieldEquals('studentId', studentId.value),
    );
    await _club.commit([
      for (final document in documents) DeleteOp(document.path),
    ]);
  });

  Future<List<StoredDocument>> _ofGroups(
    QueryFilter Function(GroupId group) filter,
  ) async => [
    for (final group in _club.groupIds)
      ...await _club.documents.query(_club.paths.attempts, filter(group)),
  ];

  /// Un parent ou un élève : les fiches de son périmètre, une requête chacune.
  Future<List<StoredDocument>> _ofLinked(
    Iterable<StudentId> students, [
    QueryFilter Function(StudentId student)? filter,
  ]) async => [
    for (final student in students)
      if (_club.studentIds.contains(student))
        ...await _club.documents.query(
          _club.paths.attempts,
          filter?.call(student) ?? FieldEquals('studentId', student.value),
        ),
  ];

  List<ExerciseAttempt> _ordered(List<StoredDocument> documents) {
    // Décoder (en écartant les illisibles, champs de tri compris) AVANT de
    // trier : un document malformé ne doit pas faire lever le tri de la liste.
    final valid = decodeValid(documents, (document) {
      AttemptDocument.createdAt(document);
      AttemptDocument.recordedAt(document);
      return (document: document, attempt: AttemptDocument.decode(document));
    })..sort((a, b) => AttemptDocument.compare(a.document, b.document));
    return [for (final entry in valid) entry.attempt];
  }
}
