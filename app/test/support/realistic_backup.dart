import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
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
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Une sauvegarde **réaliste et fictive** (aucune donnée réelle : prénoms
/// inventés, identifiants lisibles) : de quoi jouer l'import de bout en bout.
///
/// Les identifiants sont ceux d'une sauvegarde de drift (texte libre, ici
/// lisibles) : groupes `g1`…, élèves `s-g1-1`…, saisies `r-g1-1`… (une saisie
/// sur deux liée à la séance du catalogue `demi-bille-1`, identifiant
/// déterministe `groupe_AAAAMMJJ_séance`), passages `a-…`. Le fichier compte
/// `attemptsPerStudentSession` passages par élève et par séance, sur deux
/// exercices (au plus deux passages chacun : règle de la séance).
final class RealisticBackup {
  RealisticBackup({
    this.groups = 2,
    this.studentsPerGroup = 3,
    this.sessionsPerGroup = 3,
    this.attemptsPerStudentSession = 4,
    this.history = false,
    this.dayStep = 7,
    DateTime? exportedAt,
  }) : exportedAt = exportedAt ?? DateTime.utc(2026, 10, 12, 8) {
    snapshot = _build();
  }

  final int groups;
  final int studentsPerGroup;
  final int sessionsPerGroup;
  final int attemptsPerStudentSession;

  /// Ajoute une saison close avec son groupe et son archive, un bloc acquis,
  /// un bilan, un acquittement et une séance planifiée par élève ou groupe.
  final bool history;

  /// Jours entre deux séances d'un groupe.
  final int dayStep;
  final DateTime exportedAt;

  late final BackupSnapshot snapshot;

  static const season = SeasonId('season');
  static const oldSeason = SeasonId('season-old');
  static final exercise = ExerciseRef(blockId: 'puissance', number: 1);

  /// Le fichier au format courant (5).
  String get content => BackupCodec().encode(snapshot, exportedAt: exportedAt);

  GroupId groupId(int g) => GroupId('g$g');

  StudentId studentId(int g, int n) => StudentId('s-g$g-$n');

  /// Combien d'élèves, de passages, de saisies le fichier compte.
  int get studentCount => snapshot.students.length;

  int get attemptCount => snapshot.attempts.length;

  /// Les passages d'un élève, dans l'ordre du fichier.
  List<ExerciseAttempt> attemptsOf(StudentId student) => [
    for (final a in snapshot.attempts)
      if (a.studentId == student) a,
  ];

  BackupSnapshot _build() {
    final seasons = [
      Season(
        id: season,
        label: '2026-2027',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 6, 30),
      ),
      if (history)
        Season(
          id: oldSeason,
          label: '2025-2026',
          startDate: DateTime(2025, 9),
          endDate: DateTime(2026, 6, 30),
          closedOn: DateTime(2026, 6, 30),
        ),
    ];
    final students = <Student>[];
    final fileGroups = <Group>[];
    final records = <SessionRecord>[];
    final attempts = <ExerciseAttempt>[];
    final acquisitions = <BlockAcquisition>[];
    final assessments = <MaturityAssessment>[];
    final acknowledgements = <AlertAcknowledgement>[];
    final planned = <Session>[];
    for (var g = 1; g <= groups; g++) {
      final audience = g.isOdd ? Audience.children : Audience.adults;
      var group = Group(
        id: groupId(g),
        seasonId: season,
        name: 'Groupe $g',
        audience: audience,
      );
      for (var n = 1; n <= studentsPerGroup; n++) {
        final student = Student.enroll(
          id: studentId(g, n),
          firstName: 'Élève$g$n',
          audience: audience,
          since: DateTime(2026, 9),
        );
        students.add(student);
        group = group.admit(
          studentId: student.id,
          studentAudience: audience,
          from: DateTime(2026, 9),
        );
        if (history) {
          acquisitions.add(
            BlockAcquisition(
              id: AcquisitionId('q-g$g-$n'),
              studentId: student.id,
              blockId: 'puissance',
              date: DateTime(2026, 9, 15),
              source: AcquisitionSource.placement,
            ),
          );
          assessments.add(
            MaturityAssessment(
              id: AssessmentId('as-g$g-$n'),
              studentId: student.id,
              date: DateTime(2026, 9, 20),
              concentration: 3,
              endurance: 2,
              frustration: 4,
              comment: n == 1 ? 'Progresse bien' : null,
            ),
          );
        }
      }
      fileGroups.add(group);
      for (var i = 1; i <= sessionsPerGroup; i++) {
        final day = DateTime(2026, 9).add(Duration(days: dayStep * i));
        final sheet = i.isOdd ? SheetId('demi-bille-1') : null;
        final stamp =
            '${day.year}${day.month.toString().padLeft(2, '0')}'
            '${day.day.toString().padLeft(2, '0')}';
        final id = sheet == null
            ? SessionId('r-g$g-$i')
            : SessionId('g${g}_${stamp}_${sheet.value}');
        records.add(
          SessionRecord(
            id: id,
            groupId: groupId(g),
            seasonId: season,
            date: day,
            audience: audience,
            present: {
              for (var n = 1; n <= studentsPerGroup; n++) studentId(g, n),
            },
            mainBlockId: 'puissance',
            sheetId: sheet,
            tags: i == 1 ? {SessionTag.gameAppreciated} : const {},
          ),
        );
        for (var n = 1; n <= studentsPerGroup; n++) {
          for (var k = 0; k < attemptsPerStudentSession; k++) {
            attempts.add(
              ExerciseAttempt(
                id: AttemptId('a-g$g-$i-$n-$k'),
                studentId: studentId(g, n),
                sessionId: id,
                exercise: ExerciseRef(blockId: 'puissance', number: 1 + k ~/ 2),
                date: day,
                potted: 3 + (k % 3),
                total: 5,
              ),
            );
          }
        }
        if (history && i == 1) {
          acknowledgements.add(
            AlertAcknowledgement(
              id: AcknowledgementId('k-g$g'),
              studentId: studentId(g, 1),
              exercise: exercise,
              lastAttemptId: AttemptId('a-g$g-$i-1-0'),
              date: DateTime(2026, 10, 5),
            ),
          );
        }
      }
      if (history) {
        planned.add(
          Session(
            id: 'p-g$g',
            title: 'Séance du groupe $g',
            date: DateTime(2026, 11, 5),
            audience: audience,
            groupId: groupId(g),
            sheetId: SheetId('demi-bille-1'),
          ),
        );
      }
    }
    return BackupSnapshot(
      seasons: seasons,
      students: students,
      groups: fileGroups,
      sessionRecords: records,
      attempts: attempts,
      assessments: assessments,
      plannedSessions: planned,
      blockAcquisitions: acquisitions,
      alertAcknowledgements: acknowledgements,
      settings: const ClubSettings(
        passesRequired: 5,
        alertThreshold: 3,
        recallStaleSessions: 4,
        groupFailureSharePercent: 50,
        backupReminderDays: 30,
      ),
      seasonArchives: history
          ? [
              SeasonArchive(
                seasonId: oldSeason,
                audiences: [
                  AudienceArchive(
                    audience: Audience.children,
                    sessionCount: 10,
                    presenceCount: 40,
                    possiblePresenceCount: 50,
                    studentCount: 5,
                    attemptCount: 30,
                  ),
                ],
                exercises: [
                  ExerciseArchive(
                    audience: Audience.children,
                    exercise: exercise,
                    studentCount: 4,
                    attemptCount: 12,
                    potted: 40,
                    total: 60,
                  ),
                ],
              ),
            ]
          : const [],
    );
  }
}
