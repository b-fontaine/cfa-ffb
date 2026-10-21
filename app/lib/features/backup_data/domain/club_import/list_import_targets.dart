import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Un groupe du club où l'import peut écrire : son nom et son public (jamais
/// un élève).
final class ImportTarget {
  const ImportTarget({
    required this.id,
    required this.name,
    required this.audience,
  });

  final GroupId id;
  final String name;
  final Audience audience;

  /// Un groupe du fichier ne s'associe qu'à un groupe du **même public** (le
  /// planificateur refuse sinon : `audienceMismatch`).
  bool fits(OutlineGroup fileGroup) => audience == fileGroup.audience;
}

/// Cas d'usage : les groupes du club auxquels l'animateur peut **associer** un
/// groupe du fichier (FB7, ADR 0024 décision 19). Un enseignant ne voit que ses
/// groupes ; les groupes d'une saison close sont écartés (le plan les
/// refuserait : `targetSeasonClosed`).
@injectable
class ListImportTargets {
  const ListImportTargets(this._groups, this._seasons, this._scope);

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final ActiveClubScope _scope;

  Future<Result<List<ImportTarget>>> call() => runGuarded(() async {
    final role = _scope.role;
    if (role == null) return const <ImportTarget>[];
    final actor = ImportActor(role, {..._scope.groupIds});
    final closed = {
      for (final season in await _seasons.all())
        if (season.isClosed) season.id,
    };
    return [
      for (final group in await _groups.all())
        if (!closed.contains(group.seasonId) && actor.mayWriteTo(group.id))
          ImportTarget(
            id: group.id,
            name: group.name,
            audience: group.audience,
          ),
    ];
  });
}
