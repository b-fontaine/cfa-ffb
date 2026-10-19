import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_names.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Les noms de groupes lus par le dépôt de groupes du rôle courant : pour un
/// parent ou un élève, ce sont les documents des groupes de son périmètre, sans
/// appartenance (les règles les en excluent).
@LazySingleton(as: GroupNames)
class RepositoryGroupNames implements GroupNames {
  RepositoryGroupNames(this._groups);

  final GroupRepository _groups;

  @override
  Future<Map<GroupId, String>> all() async => _names(await _groups.all());

  @override
  Stream<Map<GroupId, String>> watch() => _groups.watchAll().map(_names);

  static Map<GroupId, String> _names(Iterable<Group> groups) => {
    for (final group in groups) group.id: group.name,
  };
}
