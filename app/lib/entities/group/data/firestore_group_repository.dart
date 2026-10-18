import 'package:billard_cfa/entities/group/data/group_document.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Groupes du club actif : `clubs/{c}/groups/{g}` (nom, saison, public) et une
/// appartenance datée par document `clubs/{c}/memberships/{groupId_studentId_from}`
/// (ADR 0024, A5). Choisi par `DataBackend.firestore`.
///
/// - `save` écrit le groupe (sans jamais remplacer `teacherUids`), ajoute ou
///   corrige les appartenances qui ont changé, supprime celles qui ne sont plus
///   dans le groupe, et tient à jour `groupIds` des fiches concernées (champ
///   dénormalisé que lisent les règles : un enseignant ne voit que les fiches
///   de ses groupes). Tout part dans un lot (500 écritures au plus par lot,
///   écritures idempotentes) ;
/// - `delete` supprime le groupe, ses appartenances, et retire le groupe des
///   fiches (suppression physique, ADR 0024 décision 15) ;
/// - `idsEverContaining` et `eraseStudent` interrogent les appartenances d'un
///   élève : les règles ne l'autorisent qu'à un gestionnaire (l'effacement
///   d'un élève est une opération de gestionnaire) ;
/// - `all` et `byId` dépendent du rôle : un gestionnaire lit le club ; un
///   enseignant lit les appartenances de ses groupes ; un parent ou un élève
///   lit le groupe (sans appartenances : les règles les en excluent).
///
/// Les appartenances reviennent dans un ordre canonique (élève, puis début) ;
/// la liste de `all` est triée par identifiant.
class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository(this._club);

  final ClubStore _club;

  @override
  Future<void> save(Group group) => guardStore(() async {
    final paths = _club.paths;
    final groupPath = paths.group(group.id);
    final existing = await _club.documents.get(groupPath);
    final stored = await _membershipsOf(group.id);
    final fields = GroupDocument.encode(group);

    final writes = <WriteOp>[
      if (existing != null)
        UpdateOp(groupPath, fields)
      else
        SetOp(groupPath, {...fields, ...GroupDocument.creationOnly()}),
    ];

    final wanted = <String, Fields>{
      for (final membership in group.memberships)
        paths.membership(group.id, membership.studentId, membership.from):
            GroupDocument.encodeMembership(group, membership),
    };
    final storedByPath = {for (final doc in stored) doc.path: doc};
    wanted.forEach((path, memberFields) {
      final current = storedByPath[path];
      if (current == null || !_sameFields(current.fields, memberFields)) {
        writes.add(SetOp(path, memberFields));
      }
    });
    for (final path in storedByPath.keys) {
      if (!wanted.containsKey(path)) writes.add(DeleteOp(path));
    }

    final students = {
      for (final membership in group.memberships) membership.studentId,
      for (final doc in stored) ?_studentOf(doc),
    };
    final current = {
      for (final membership in group.memberships)
        if (membership.to == null) membership.studentId,
    };
    writes.addAll(await _syncStudents(group.id, students, current));
    await _club.commit(writes);
  });

  @override
  Future<Group?> byId(GroupId id) => guardStore(() async {
    final document = await _club.documents.get(_club.paths.group(id));
    if (document == null) return null;
    return GroupDocument.decode(document, await _membershipsOf(id));
  });

  @override
  Future<List<Group>> all() => guardStore(() async {
    final paths = _club.paths;
    if (_club.manages) {
      final groups = await _club.documents.list(paths.groups);
      final memberships = await _club.documents.list(paths.memberships);
      return [
        for (final group in groups)
          GroupDocument.decode(group, [
            for (final doc in memberships)
              if (doc.fields['groupId'] == group.id) doc,
          ]),
      ];
    }
    return [
      for (final id in _club.groupIds)
        ?await _decodeIfPresent(paths.group(id), id),
    ]..sort((a, b) => a.id.value.compareTo(b.id.value));
  });

  Future<Group?> _decodeIfPresent(String path, GroupId id) async {
    final document = await _club.documents.get(path);
    if (document == null) return null;
    return GroupDocument.decode(document, await _membershipsOf(id));
  }

  @override
  Future<void> delete(GroupId id) => guardStore(() async {
    final paths = _club.paths;
    final stored = await _membershipsOf(id);
    final writes = <WriteOp>[
      for (final doc in stored) DeleteOp(doc.path),
      DeleteOp(paths.group(id)),
      ...await _syncStudents(id, {
        for (final doc in stored) ?_studentOf(doc),
      }, const {}),
    ];
    await _club.commit(writes);
  });

  @override
  Future<Set<GroupId>> idsEverContaining(StudentId studentId) =>
      guardStore(() async {
        final documents = await _club.documents.query(
          _club.paths.memberships,
          FieldEquals('studentId', studentId.value),
        );
        return {
          for (final doc in documents)
            if (doc.fields['groupId'] case final String group) GroupId(group),
        };
      });

  @override
  Future<void> eraseStudent(StudentId studentId) => guardStore(() async {
    final documents = await _club.documents.query(
      _club.paths.memberships,
      FieldEquals('studentId', studentId.value),
    );
    await _club.commit([for (final doc in documents) DeleteOp(doc.path)]);
  });

  /// Les appartenances d'un groupe : un gestionnaire et un enseignant les
  /// lisent ; un parent ou un élève, non (règles) : liste vide.
  Future<List<StoredDocument>> _membershipsOf(GroupId id) {
    if (_club.role == Role.student || _club.role == Role.guardian) {
      return Future.value(const []);
    }
    return _club.documents.query(
      _club.paths.memberships,
      FieldEquals('groupId', id.value),
    );
  }

  /// Met `groupIds` des fiches [students] d'accord avec les appartenances
  /// ouvertes de [group] ([current]) : ajoute ou retire [group] par union ou
  /// retrait atomique ; ne touche pas aux autres groupes de la fiche ; ignore
  /// une fiche absente. La lecture ne sert qu'à sauter les fiches déjà à jour.
  Future<List<WriteOp>> _syncStudents(
    GroupId group,
    Set<StudentId> students,
    Set<StudentId> current,
  ) async {
    final writes = <WriteOp>[];
    for (final id in students) {
      final path = _club.paths.student(id);
      final document = await _club.documents.get(path);
      if (document == null) continue;
      final groups = [
        for (final item in DocumentValues(
          path,
          document.fields,
        ).list('groupIds'))
          if (item is String) item,
      ];
      final has = groups.contains(group.value);
      final wants = current.contains(id);
      if (has == wants) continue;
      // Union ou retrait côté serveur : sans réécrire la liste lue, deux
      // gestionnaires qui enregistrent des groupes différents s'additionnent.
      writes.add(
        UpdateOp(path, {
          'groupIds': wants
              ? ArrayUnion([group.value])
              : ArrayRemove([group.value]),
        }),
      );
    }
    return writes;
  }

  static StudentId? _studentOf(StoredDocument doc) =>
      switch (doc.fields['studentId']) {
        final String id when id.isNotEmpty => StudentId(id),
        _ => null,
      };

  static bool _sameFields(Fields a, Fields b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
