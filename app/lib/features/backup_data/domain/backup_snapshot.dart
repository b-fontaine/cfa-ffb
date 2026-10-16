import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_snapshot.freezed.dart';

/// Contenu complet d'une sauvegarde : toutes les données du club, hors
/// métadonnées de persistance (horodatages, suppressions logiques).
///
/// [blockAcquisitions] est obligatoire (ADR 0008) : un oubli à la
/// construction ne compile pas. [settings] (ADR 0012) est absent d'un fichier
/// du format 1 : les réglages en place restent alors inchangés.
/// [alertAcknowledgements] (ADR 0013) est `null` pour un fichier des formats 1
/// et 2, qui ne les connaissent pas : l'import efface alors les acquittements
/// en place ; un fichier du format 3 porte toujours la liste (éventuellement
/// vide), qui est ajoutée à ceux en place.
/// [seasonArchives] (ADR 0019) est obligatoire à la construction, comme
/// [blockAcquisitions] : un oubli ne compile pas. Un fichier des formats 1 à 3
/// n'en porte pas (liste vide) ; l'archive d'un fichier du format 4 remplace
/// celle en place pour sa saison.
@freezed
abstract class BackupSnapshot with _$BackupSnapshot {
  const factory BackupSnapshot({
    required List<BlockAcquisition> blockAcquisitions,
    required List<SeasonArchive> seasonArchives,
    @Default([]) List<Season> seasons,
    @Default([]) List<Student> students,
    @Default([]) List<Group> groups,
    @Default([]) List<SessionRecord> sessionRecords,
    @Default([]) List<ExerciseAttempt> attempts,
    @Default([]) List<MaturityAssessment> assessments,
    @Default([]) List<Session> plannedSessions,
    ClubSettings? settings,
    List<AlertAcknowledgement>? alertAcknowledgements,
  }) = _BackupSnapshot;
}
