import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Le groupe et la saison **dénormalisés** dans une donnée d'élève (ADR 0024,
/// décision 14 : une règle ne filtre pas les champs et ne parcourt pas une
/// liste, `groupOwned` / `studentOwned` les exigent).
final class DataOwner {
  const DataOwner(this.group, this.season);

  final GroupId group;
  final SeasonId season;
}

/// Retrouve le propriétaire d'une donnée à écrire, depuis les documents du
/// club actif (jamais depuis un cache : le club est celui de l'appel).
///
/// - un **passage** appartient au groupe et à la saison de **sa séance** ;
/// - le **bloc acquis**, le **bilan** et l'**acquittement** d'un élève (sans
///   séance) appartiennent à **un groupe de sa fiche** : pour un enseignant,
///   parmi **ses** groupes (les règles exigent qu'il écrive dans l'un des
///   siens) ; puis la saison **ouverte** la plus récente, puis l'identifiant.
///
/// Chaque lecture passe d'abord par le **cache local**
/// (`ClubStore.cachedOrGet`) : hors ligne, les documents que l'animateur a
/// sous les yeux suffisent, et l'écriture n'attend pas le réseau (FB5).
///
/// Budget de lectures : une (séance) ; ou la fiche, ses groupes et leurs
/// saisons (`1 + 2n`, `n` petit : une fiche est dans un ou deux groupes).
final class OwnerResolver {
  const OwnerResolver(this._club);

  final ClubStore _club;

  /// Le propriétaire de la séance [id] ; `StoreFailure(notFound)` si elle
  /// n'existe pas (les passages ne naissent que d'une séance ouverte).
  Future<DataOwner> ofSession(SessionId id) async {
    final path = _club.paths.record(id);
    final document = await _club.cachedOrGet(path);
    if (document == null) throw StoreFailure(StoreFailureCode.notFound, path);
    return _owner(document);
  }

  /// Le propriétaire des données de l'élève [id] hors séance.
  Future<DataOwner> ofStudent(StudentId id) async {
    final paths = _club.paths;
    final student = await _club.cachedOrGet(paths.student(id));
    if (student == null) {
      throw StoreFailure(StoreFailureCode.notFound, paths.student(id));
    }
    final scope = {for (final group in _club.groupIds) group.value};
    final groups = [
      for (final raw in DocumentValues(
        student.path,
        student.fields,
      ).list('groupIds'))
        if (raw is String &&
            (_club.role != Role.teacher || scope.contains(raw)))
          raw,
    ];
    if (groups.isEmpty) {
      throw StoreFailure(
        StoreFailureCode.other,
        '${student.path}: no group to own the data',
      );
    }
    final candidates = <({DataOwner owner, bool open, DateTime start})>[];
    for (final raw in groups) {
      final group = await _club.cachedOrGet(paths.group(GroupId(raw)));
      if (group == null) continue;
      final season = SeasonId(
        DocumentValues(group.path, group.fields).string('seasonId'),
      );
      final document = await _club.cachedOrGet(paths.season(season));
      final values = document == null
          ? null
          : DocumentValues(document.path, document.fields);
      candidates.add((
        owner: DataOwner(GroupId(raw), season),
        open: values?.optDate('closedOn') == null,
        start:
            values?.optDate('startDate') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      ));
    }
    if (candidates.isEmpty) {
      throw StoreFailure(
        StoreFailureCode.notFound,
        '${student.path}: groups not found',
      );
    }
    candidates.sort((a, b) {
      if (a.open != b.open) return a.open ? -1 : 1;
      final byStart = b.start.compareTo(a.start);
      return byStart != 0
          ? byStart
          : a.owner.group.value.compareTo(b.owner.group.value);
    });
    return candidates.first.owner;
  }

  static DataOwner _owner(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    return DataOwner(
      GroupId(values.string('groupId')),
      SeasonId(values.string('seasonId')),
    );
  }
}
