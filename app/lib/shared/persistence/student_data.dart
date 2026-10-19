import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/data_owner.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Lecture et écriture d'une collection de **données d'élève** du club actif
/// (blocs acquis, bilans, acquittements) : documents portant `groupId`,
/// `seasonId` et `studentId` (ADR 0024, décision 14).
///
/// Lecture selon le rôle, avec les seules requêtes que les règles acceptent :
/// - directeur et administrateur : le club (liste, ou égalité sur
///   `studentId`) ;
/// - enseignant : **un groupe à la fois** (égalité sur `groupId`, avec
///   `studentId` pour une fiche) ;
/// - parent et élève : la **fiche liée** (égalité sur `studentId`) si
///   [familyMayRead], sinon rien (bilans et alertes exclus, B2) ; jamais
///   une requête que les règles refuseraient.
final class StudentData {
  const StudentData(
    this._club,
    this._collection, {
    required this.familyMayRead,
  });

  final ClubStore _club;
  final String Function(ClubPaths paths) _collection;

  /// Un parent ou un élève lit-il cette collection pour sa fiche liée ?
  final bool familyMayRead;

  String get _path => _collection(_club.paths);

  Future<List<StoredDocument>> forStudent(StudentId student) async {
    if (_club.manages) {
      return await _club.documents.query(
        _path,
        FieldEquals('studentId', student.value),
      );
    }
    if (_club.role == Role.teacher) {
      return [
        for (final group in _club.groupIds)
          ...await _club.documents.query(
            _path,
            AllEqual([
              FieldEquals('groupId', group.value),
              FieldEquals('studentId', student.value),
            ]),
          ),
      ];
    }
    if (!familyMayRead || !_club.studentIds.contains(student)) return const [];
    return await _club.documents.query(
      _path,
      FieldEquals('studentId', student.value),
    );
  }

  Future<List<StoredDocument>> all() async {
    if (_club.manages) return await _club.documents.list(_path);
    if (_club.role == Role.teacher) {
      return [
        for (final group in _club.groupIds)
          ...await _club.documents.query(
            _path,
            FieldEquals('groupId', group.value),
          ),
      ];
    }
    if (!familyMayRead) return const [];
    return [
      for (final student in _club.studentIds)
        ...await _club.documents.query(
          _path,
          FieldEquals('studentId', student.value),
        ),
    ];
  }

  /// Suit [forStudent] : les mêmes requêtes, par rôle, en flux.
  Stream<List<StoredDocument>> watchForStudent(StudentId student) {
    final path = _path;
    return _club.watchSources([
      if (_club.manages)
        ReadSource.query(path, FieldEquals('studentId', student.value))
      else if (_club.role == Role.teacher)
        for (final group in _club.groupIds)
          ReadSource.query(
            path,
            AllEqual([
              FieldEquals('groupId', group.value),
              FieldEquals('studentId', student.value),
            ]),
          )
      else if (familyMayRead && _club.studentIds.contains(student))
        ReadSource.query(path, FieldEquals('studentId', student.value)),
    ]);
  }

  /// Suit [all] : les mêmes requêtes, par rôle, en flux.
  Stream<List<StoredDocument>> watchAll() {
    final path = _path;
    return _club.watchSources([
      if (_club.manages)
        ReadSource.collection(path)
      else if (_club.role == Role.teacher)
        for (final group in _club.groupIds)
          ReadSource.query(path, FieldEquals('groupId', group.value))
      else if (familyMayRead)
        for (final student in _club.studentIds)
          ReadSource.query(path, FieldEquals('studentId', student.value)),
    ]);
  }

  /// Les documents de l'élève, à effacer (réservé aux gestionnaires).
  Future<void> eraseStudent(StudentId student) async {
    final documents = await _club.documents.query(
      _path,
      FieldEquals('studentId', student.value),
    );
    await _club.commit([
      for (final document in documents) DeleteOp(document.path),
    ]);
  }

  /// Écrit [path] : **remplace** le document s'il existe (le propriétaire,
  /// groupe et saison, reste celui du document), sinon le crée chez le
  /// propriétaire rendu par [resolve] ; [fields] sait si le document existe
  /// déjà. Fusion : un champ vidé (`null`) est écrit, les champs inconnus
  /// restent.
  ///
  /// **Possible hors ligne** (FB5) : le document cible se lit dans le cache
  /// local, **puis sur le serveur** quand le cache ne l'a pas (cache froid
  /// après une connexion ou un changement de compte : un document qui existe
  /// ne doit jamais être réécrit comme une création, en ligne). Seul
  /// `unavailable` (hors ligne) est traité comme « absent » : la création se
  /// fait alors sans réseau, chez le propriétaire rendu par [resolve] (fiche,
  /// groupes, séance que l'animateur a sous les yeux). Hors ligne, un
  /// document du serveur absent du cache est donc écrit comme une création, par
  /// fusion ; si son propriétaire diffère, les règles refusent la mise à jour
  /// (`sameOwnership`) et le refus remonte par `SendStatus.hasFailure`
  /// (détail : `SendTracker.lastFailure`).
  Future<void> upsert(
    String path,
    Fields Function(DataOwner owner, {required bool exists}) fields,
    Future<DataOwner> Function() resolve,
  ) async {
    StoredDocument? found;
    try {
      found = await _club.cachedOrGet(path);
    } on StoreFailure catch (failure) {
      if (failure.code != StoreFailureCode.unavailable) rethrow;
    }
    final existing = found;
    final owner = existing == null
        ? await resolve()
        : () {
            final values = DocumentValues(existing.path, existing.fields);
            return DataOwner(
              GroupId(values.string('groupId')),
              SeasonId(values.string('seasonId')),
            );
          }();
    await _club.commit([
      SetOp(path, fields(owner, exists: existing != null), merge: true),
    ]);
  }
}
