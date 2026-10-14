import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Règles métier appliquées à une sauvegarde décodée, avant toute écriture.
///
/// Le décodeur ne vérifie que la forme, l'unicité et les références internes.
/// Ici, on rejoue les garde-fous des cas d'usage (ouverture de séance, saisie
/// d'un passage, bilan) : sans eux, un fichier corrompu ou malveillant ferait
/// lever `StudentProgress.derive` à chaque ouverture de la fiche d'un élève.
///
/// Codes : `backupInconsistent` pour une référence qui ne se résout pas (au
/// catalogue, à la séance, au groupe) ; `backupInvalid` pour une valeur qui
/// viole une règle (plafond de passages, période, public, date). Une séance
/// planifiée ou saisie dont la séance du catalogue est inconnue est refusée
/// par `backupUnknownSheet`, pour nommer la cause à l'animateur.
@injectable
class BackupRules {
  BackupRules(this._catalogue, this._sheets, this._config, this._clock);

  final CatalogueRepository _catalogue;
  final SessionSheetRepository _sheets;
  final RulesConfig _config;
  final Clock _clock;

  static const _invalid = InvariantViolation(InvariantCode.backupInvalid);
  static const _inconsistent = InvariantViolation(
    InvariantCode.backupInconsistent,
  );
  static const _unknownSheet = InvariantViolation(
    InvariantCode.backupUnknownSheet,
  );
  static const _unknownBlock = InvariantViolation(
    InvariantCode.backupUnknownBlock,
  );

  Future<void> check(BackupSnapshot snapshot) async {
    final catalogue = await _catalogue.load();
    _checkSessions(snapshot, catalogue);
    _checkAttempts(snapshot, catalogue);
    _checkAssessments(snapshot);
    _checkAcquisitions(snapshot, catalogue);
    _checkPlanned(snapshot);
    await _checkSheets(snapshot);
  }

  void _checkSessions(BackupSnapshot snapshot, ExerciseCatalogue catalogue) {
    final seasons = {for (final s in snapshot.seasons) s.id: s};
    final groups = {for (final g in snapshot.groups) g.id: g};
    for (final session in snapshot.sessionRecords) {
      final group = groups[session.groupId];
      final season = seasons[session.seasonId];
      if (group == null || season == null) throw _inconsistent;
      if (group.seasonId != session.seasonId) throw _inconsistent;
      if (!season.contains(session.date)) throw _invalid;
      if (session.audience != group.audience) throw _invalid;
      final blocks = [session.mainBlockId, session.recallBlockId].nonNulls;
      if (blocks.any((id) => catalogue.blockById(id) == null)) {
        throw _inconsistent;
      }
    }
  }

  void _checkAttempts(BackupSnapshot snapshot, ExerciseCatalogue catalogue) {
    final sessions = {for (final s in snapshot.sessionRecords) s.id: s};
    final indexes = <(String, String, ExerciseRef), Set<int>>{};
    for (final attempt in snapshot.attempts) {
      if (catalogue.exercise(attempt.exercise) == null) throw _inconsistent;
      final session = sessions[attempt.sessionId];
      if (session == null) throw _inconsistent;
      if (!session.present.contains(attempt.studentId)) throw _inconsistent;
      final key = (
        attempt.sessionId.value,
        attempt.studentId.value,
        attempt.exercise,
      );
      final taken = indexes.putIfAbsent(key, () => {});
      if (attempt.passIndex > _config.maxPassesPerExercisePerSession ||
          !taken.add(attempt.passIndex)) {
        throw _invalid;
      }
    }
  }

  /// Une séance planifiée pour un groupe prend le public du groupe et tombe
  /// dans sa saison (règles de `PlanSession`).
  void _checkPlanned(BackupSnapshot snapshot) {
    final seasons = {for (final s in snapshot.seasons) s.id: s};
    final groups = {for (final g in snapshot.groups) g.id: g};
    for (final planned in snapshot.plannedSessions) {
      final groupId = planned.groupId;
      if (groupId == null) continue;
      final group = groups[groupId];
      final season = group == null ? null : seasons[group.seasonId];
      if (group == null || season == null) throw _inconsistent;
      if (planned.audience != group.audience) throw _invalid;
      if (!season.contains(planned.date)) throw _invalid;
    }
  }

  /// Une séance planifiée ou saisie ne peut noter qu'une séance du catalogue
  /// connue : l'application n'étant pas encore livrée, aucun identifiant d'une
  /// version antérieure n'est à tolérer (erreur claire, `backupUnknownSheet`,
  /// plutôt qu'un lien orphelin).
  Future<void> _checkSheets(BackupSnapshot snapshot) async {
    final linked = {
      ...snapshot.plannedSessions.map((session) => session.sheetId).nonNulls,
      ...snapshot.sessionRecords.map((session) => session.sheetId).nonNulls,
    };
    if (linked.isEmpty) return;
    final known = {for (final sheet in await _sheets.getAll()) sheet.id};
    if (!known.containsAll(linked)) throw _unknownSheet;
  }

  /// Un bloc acquis vise un bloc du catalogue (`backupUnknownBlock`, comme
  /// `backupUnknownSheet`) et ne peut pas être daté dans le futur ; la date
  /// normalisée au jour et la source sont déjà vérifiées au décodage.
  void _checkAcquisitions(
    BackupSnapshot snapshot,
    ExerciseCatalogue catalogue,
  ) {
    final today = _clock.today();
    for (final acquisition in snapshot.blockAcquisitions) {
      if (catalogue.blockById(acquisition.blockId) == null) {
        throw _unknownBlock;
      }
      if (acquisition.date.isAfter(today)) throw _invalid;
    }
  }

  void _checkAssessments(BackupSnapshot snapshot) {
    final today = _clock.today();
    for (final assessment in snapshot.assessments) {
      if (assessment.date.isAfter(today)) throw _invalid;
    }
  }
}
