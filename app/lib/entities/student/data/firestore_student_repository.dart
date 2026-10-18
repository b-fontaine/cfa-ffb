import 'package:billard_cfa/entities/student/data/student_document.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Fiches élèves du club actif dans `clubs/{c}/students/{id}` : **le même
/// document** que `StoreStudentDirectory` publie à l'invitation (même
/// identifiant local). Choisi par `DataBackend.firestore`.
///
/// - `save` crée la fiche (sans groupe courant, date du serveur) ou met à jour
///   ses champs propres (prénom, public, historique) sans toucher `groupIds`
///   ni `createdAt` : les groupes tiennent le premier, le serveur le second ;
/// - `delete` et `erase` suppriment le document (suppression **physique**, ADR
///   0024 décision 15) ; l'effacement en cascade des données de l'élève est le
///   lot FB8 ;
/// - `all` dépend du rôle, parce que les règles n'autorisent pas la même
///   requête à tous : le directeur et l'administrateur listent le club ;
///   l'enseignant interroge `groupIds` (`array-contains-any` sur ses groupes) ;
///   un parent ou un élève lit ses fiches liées une à une ;
/// - la liste est triée par inscription puis identifiant (ordre canonique, pas
///   l'ordre de première sauvegarde de la mémoire).
class FirestoreStudentRepository implements StudentRepository {
  FirestoreStudentRepository(this._club);

  /// `array-contains-any` accepte 30 valeurs au plus (Firestore).
  static const _maxContainsAny = 30;

  final ClubStore _club;

  @override
  Future<void> save(Student student) => guardStore(() async {
    final path = _club.paths.student(student.id);
    final exists = await _club.documents.get(path) != null;
    final fields = StudentDocument.encode(student);
    // Fusion : même si la lecture ne voit pas une fiche qui existe
    // (concurrence,
    // cache hors ligne), `groupIds` n'est jamais remplacé (`ArrayUnion([])` le
    // crée vide ou le laisse tel quel). Seule `createdAt` dépend de la lecture.
    await _club.documents.commit([
      SetOp(path, {
        ...fields,
        'groupIds': const ArrayUnion([]),
        if (!exists) ...StudentDocument.creationOnly(),
      }, merge: true),
    ]);
  });

  @override
  Future<Student?> byId(StudentId id) => guardStore(() async {
    final document = await _club.documents.get(_club.paths.student(id));
    return document == null ? null : StudentDocument.decode(document);
  });

  @override
  Future<List<Student>> all() => guardStore(() async {
    final paths = _club.paths;
    final documents = _club.manages
        ? await _club.documents.list(paths.students)
        : await _scoped(paths.students);
    return [for (final document in documents) StudentDocument.decode(document)]
      ..sort(StudentDocument.compare);
  });

  Future<List<StoredDocument>> _scoped(String collection) async {
    switch (_club.role) {
      case Role.teacher:
        final groups = [for (final id in _club.groupIds) id.value];
        final found = <String, StoredDocument>{};
        for (var i = 0; i < groups.length; i += _maxContainsAny) {
          final chunk = groups.sublist(
            i,
            i + _maxContainsAny > groups.length
                ? groups.length
                : i + _maxContainsAny,
          );
          for (final document in await _club.documents.query(
            collection,
            FieldArrayContainsAny('groupIds', chunk),
          )) {
            found[document.path] = document;
          }
        }
        return found.values.toList();
      case Role.student || Role.guardian:
        return [
          for (final id in _club.studentIds)
            ?await _club.documents.get('$collection/${id.value}'),
        ];
      case Role.director || Role.admin || null:
        return const [];
    }
  }

  @override
  Future<void> delete(StudentId id) => _remove(id);

  @override
  Future<void> erase(StudentId id) => _remove(id);

  Future<void> _remove(StudentId id) => guardStore(
    () => _club.documents.commit([DeleteOp(_club.paths.student(id))]),
  );
}
