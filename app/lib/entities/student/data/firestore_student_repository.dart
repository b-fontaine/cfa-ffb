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
/// - `create` (l'inscription seule) crée la fiche, sans groupe courant, avec la
///   date du serveur que les règles exigent à la création ; `save` met à jour
///   ses champs propres (prénom, public, historique) sans toucher `groupIds`
///   ni `createdAt`, et **échoue sur une fiche absente** : une fiche effacée ne
///   revient jamais avec son prénom par une édition rejouée ;
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
  Future<void> create(Student student) => guardStore(() async {
    // Fusion : même si la lecture ne voit pas une fiche qui existe
    // (concurrence, cache hors ligne), `groupIds` n'est jamais remplacé
    // (`ArrayUnion([])` le crée vide ou le laisse tel quel).
    await _club.commit([
      SetOp(_club.paths.student(student.id), {
        ...StudentDocument.encode(student),
        'groupIds': const ArrayUnion([]),
        ...StudentDocument.creationOnly(),
      }, merge: true),
    ]);
  });

  @override
  Future<void> save(Student student) => guardStore(
    // Une mise à jour : sur une fiche absente (effacée par un autre appareil),
    // elle échoue (`notFound`) au lieu de la recréer avec son prénom.
    () => _club.commit([
      UpdateOp(
        _club.paths.student(student.id),
        StudentDocument.encode(student),
      ),
    ]),
  );

  @override
  Future<Student?> byId(StudentId id) => guardStore(() async {
    final document = await _club.get(_club.paths.student(id));
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

  @override
  Stream<Student?> watchById(StudentId id) => guardStoreStream(
    () => _club
        .watchDocument(_club.paths.student(id))
        .map(
          (update) => update.document == null
              ? null
              : StudentDocument.decode(update.document!),
        ),
  );

  /// Les mêmes lectures que [all], par rôle (les règles n'autorisent pas la
  /// même requête à tous), suivies en flux : un gestionnaire suit la
  /// collection, un enseignant les fiches de ses groupes
  /// (`array-contains-any`, par tranches de 30), un parent ou un élève ses
  /// fiches liées une à une.
  @override
  Stream<List<Student>> watchAll() => guardStoreStream(() {
    final collection = _club.paths.students;
    return _club
        .watchSources(_sources(collection))
        .map(
          (documents) => [
            for (final document in {
              for (final document in documents) document.path: document,
            }.values)
              StudentDocument.decode(document),
          ]..sort(StudentDocument.compare),
        );
  });

  List<ReadSource> _sources(String collection) {
    if (_club.manages) return [ReadSource.collection(collection)];
    return switch (_club.role) {
      Role.teacher => [
        for (final chunk in _chunks([
          for (final id in _club.groupIds) id.value,
        ]))
          ReadSource.query(
            collection,
            FieldArrayContainsAny('groupIds', chunk),
          ),
      ],
      Role.student || Role.guardian => [
        for (final id in _club.studentIds)
          ReadSource.document('$collection/${id.value}'),
      ],
      Role.director || Role.admin || null => const [],
    };
  }

  static Iterable<List<String>> _chunks(List<String> values) sync* {
    for (var i = 0; i < values.length; i += _maxContainsAny) {
      yield values.sublist(
        i,
        i + _maxContainsAny > values.length
            ? values.length
            : i + _maxContainsAny,
      );
    }
  }

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
            ?await _club.get('$collection/${id.value}'),
        ];
      case Role.director || Role.admin || null:
        return const [];
    }
  }

  @override
  Future<void> delete(StudentId id) => _remove(id);

  @override
  Future<void> erase(StudentId id) => _remove(id);

  Future<void> _remove(StudentId id) =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.student(id))]));
}
