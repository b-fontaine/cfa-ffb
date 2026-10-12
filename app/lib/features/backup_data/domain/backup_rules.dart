import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
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
/// viole une règle (plafond de passages, période, public, date).
@injectable
class BackupRules {
  BackupRules(this._catalogue, this._config, this._clock);

  final CatalogueRepository _catalogue;
  final RulesConfig _config;
  final Clock _clock;

  static const _invalid = InvariantViolation(InvariantCode.backupInvalid);
  static const _inconsistent = InvariantViolation(
    InvariantCode.backupInconsistent,
  );

  Future<void> check(BackupSnapshot snapshot) async {
    final catalogue = await _catalogue.load();
    _checkSessions(snapshot, catalogue);
    _checkAttempts(snapshot, catalogue);
    _checkAssessments(snapshot);
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

  void _checkAssessments(BackupSnapshot snapshot) {
    final today = _clock.today();
    for (final assessment in snapshot.assessments) {
      if (assessment.date.isAfter(today)) throw _invalid;
    }
  }
}
