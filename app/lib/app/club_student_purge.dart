import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// La purge d'un élève dans un **club Firestore** (FB8, ADR 0024 décision 19).
/// Une seule liste de ce qui se rapporte à un élève *dans le club* ; elle sert
/// l'effacement d'un élève et la clôture de saison. Choisie par
/// `DataBackendModule` avec `DataBackend.firestore`. La progression **locale**
/// des séances guidées (sur l'appareil) s'efface par les mêmes liens que dans
/// `EraseStudent`, par le même port (`RunProgressRepository.eraseLinked`).
///
/// Ce qui se rapporte à l'élève, par requête (un gestionnaire les lit toutes) :
/// - ses passages, blocs acquis, bilans et acquittements (`studentId`) et ses
///   appartenances datées (`studentId`) : **suppression** ;
/// - les saisies où il est présent (`presentStudentIds`) : l'identifiant est
///   **retiré de la liste** par `arrayRemove`, jamais par lecture puis
///   écriture ;
/// - les comptes parent et élève qui y sont liés (`members.studentIds`) : le
///   compte qui n'aurait plus aucun élève lié est **supprimé**, les autres
///   perdent le lien (`arrayRemove`) ; le compte d'authentification subsiste
///   (suppression de compte, partie B) ;
/// - la progression locale des séances guidées liée à l'élève (groupes de ses
///   appartenances, saisies où il est présent, séances planifiées de ces
///   groupes) : `eraseLinked`, avant les suppressions.
///
/// Les étiquettes de saisie (ADR 0023) ne nomment personne : elles restent. La
/// fiche est supprimée **en dernier** ([removeRecords]).
///
/// **Limites** (règles Firestore, ADR 0024) : une règle ne parcourt pas une
/// liste, donc un appareil retardataire peut encore **ajouter** l'identifiant
/// aux présents d'une saisie pendant l'effacement ; l'étape de purge se rejoue
/// jusqu'à ce que la requête ne trouve plus rien, juste avant la suppression
/// de la fiche, ce qui réduit la fenêtre sans la fermer. Les invitations non
/// utilisées qui citent la fiche ne se listent pas (`list: false`) et le
/// journal local d'invitations ne garde pas l'élève cité : la règle
/// d'utilisation d'une invitation refuse alors toute fiche absente ou en
/// cours d'effacement, et elles sont purgées à l'expiration (partie B).
class ClubStudentPurge implements StudentPurge {
  ClubStudentPurge(this._club, this._runProgress);

  final ClubStore _club;
  final RunProgressRepository _runProgress;

  @override
  Future<StudentPurgePreview> preview(StudentId id) => guardStore(() async {
    final paths = _club.paths;
    Future<int> count(String collection, QueryFilter filter) async =>
        (await _club.documents.query(collection, filter)).length;
    final by = FieldEquals('studentId', id.value);
    return StudentPurgePreview(
      attempts: await count(paths.attempts, by),
      acquisitions: await count(paths.acquisitions, by),
      assessments: await count(paths.assessments, by),
      acknowledgements: await count(paths.acknowledgements, by),
      memberships: await count(paths.memberships, by),
      presences: await count(paths.records, _present(id)),
      accountLinks: await count(paths.members, _linked(id)),
    );
  });

  @override
  Future<bool> exists(StudentId id) =>
      guardStore(() async => await _club.get(_club.paths.student(id)) != null);

  @override
  Future<Set<StudentId>> flagged() => guardStore(() async {
    final documents = await _club.documents.query(
      _club.paths.students,
      const FieldEquals('erasing', true),
    );
    return {for (final document in documents) StudentId(document.id)};
  });

  @override
  OperationLot flag(Set<StudentId> ids) => OperationLot(
    writes: ids.length,
    apply: () => guardStore(
      () => _club.commit([
        for (final id in ids)
          UpdateOp(_club.paths.student(id), const {'erasing': true}),
      ]),
    ),
  );

  @override
  Future<List<OperationLot>> purgeLots(
    Set<StudentId> ids, {
    required int maxWrites,
  }) => guardStore(() async {
    final paths = _club.paths;
    final accounts = <String, StoredDocument>{};
    final groups = <GroupId>{};
    final records = <SessionId>{};
    final presences = <WriteOp>[];
    final deletions = <WriteOp>[];
    for (final id in ids) {
      final by = FieldEquals('studentId', id.value);
      for (final member in await _club.documents.query(
        paths.members,
        _linked(id),
      )) {
        accounts[member.path] = member;
      }
      for (final membership in await _club.documents.query(
        paths.memberships,
        by,
      )) {
        final group = membership.fields['groupId'];
        if (group is String) groups.add(GroupId(group));
      }
      for (final record in await _club.documents.query(
        paths.records,
        _present(id),
      )) {
        records.add(SessionId(record.id));
        presences.add(
          UpdateOp(record.path, {
            'presentStudentIds': ArrayRemove([id.value]),
          }),
        );
      }
      for (final collection in [
        paths.attempts,
        paths.acquisitions,
        paths.assessments,
        paths.acknowledgements,
        paths.memberships,
      ]) {
        deletions.addAll([
          for (final document in await _club.documents.query(collection, by))
            DeleteOp(document.path),
        ]);
      }
    }
    await _eraseLocalProgress(groups, records);
    // L'accès des comptes liés est coupé en premier, tous élèves confondus.
    final operations = [
      ..._accountOperations(accounts.values, ids),
      ...presences,
      ...deletions,
    ];
    return [
      for (var i = 0; i < operations.length; i += maxWrites)
        _lot(
          operations.sublist(
            i,
            i + maxWrites > operations.length
                ? operations.length
                : i + maxWrites,
          ),
        ),
    ];
  });

  /// Le sort des comptes liés aux élèves [ids] : un compte élève ou parent qui
  /// n'aurait plus **aucun** élève lié une fois [ids] retirés est
  /// **supprimé** (son `displayName` est en pratique le nom de l'enfant :
  /// donnée de la personne dont on efface les données) ; les autres perdent
  /// seulement le lien (`arrayRemove`). Le compte d'authentification subsiste
  /// : il se supprime par la suppression de compte (partie B).
  Iterable<WriteOp> _accountOperations(
    Iterable<StoredDocument> accounts,
    Set<StudentId> ids,
  ) sync* {
    final erased = {for (final id in ids) id.value};
    for (final account in accounts) {
      final linked = account.fields['studentIds'];
      final left = linked is List
          ? [
              for (final value in linked)
                if (!erased.contains(value)) value,
            ]
          : const <Object?>[];
      final role = account.fields['role'];
      if (left.isEmpty && (role == 'student' || role == 'guardian')) {
        yield DeleteOp(account.path);
      } else {
        yield UpdateOp(account.path, {
          'studentIds': ArrayRemove([for (final id in erased) id]),
        });
      }
    }
  }

  /// La progression locale des séances guidées (sur l'appareil, jamais dans le
  /// club) liée à l'élève, par ses liens **calculés avant** que les
  /// appartenances et les présences ne disparaissent : les mêmes liens, par le
  /// même port, que `EraseStudent` (ADR 0020 § 7), donc une seule liste.
  /// Rejouable : sans lien trouvé, rien n'est effacé.
  Future<void> _eraseLocalProgress(
    Set<GroupId> groups,
    Set<SessionId> records,
  ) async {
    if (groups.isEmpty && records.isEmpty) return;
    final planned = <String>{};
    for (final group in groups) {
      for (final session in await _club.documents.query(
        _club.paths.sessions,
        FieldEquals('groupId', group.value),
      )) {
        planned.add(session.id);
      }
    }
    await _runProgress.eraseLinked(
      groups: groups,
      records: records,
      plannedSessions: planned,
    );
  }

  @override
  OperationLot removeRecords(Set<StudentId> ids) => OperationLot(
    writes: ids.length,
    apply: () => guardStore(
      () => _club.commit([
        for (final id in ids) DeleteOp(_club.paths.student(id)),
      ]),
    ),
  );

  OperationLot _lot(List<WriteOp> operations) => OperationLot(
    writes: operations.length,
    apply: () => guardStore(() => _club.commit(operations)),
  );

  static QueryFilter _present(StudentId id) =>
      FieldArrayContainsAny('presentStudentIds', [id.value]);

  static QueryFilter _linked(StudentId id) =>
      FieldArrayContainsAny('studentIds', [id.value]);
}
