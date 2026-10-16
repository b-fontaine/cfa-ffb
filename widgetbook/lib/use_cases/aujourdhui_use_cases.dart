import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/upcoming_cards.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/review_session/presentation/ui/session_review_view.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/running_session_card.dart';
import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/next_sheet_card.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_list.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/watched_students_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/week_summary_card.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/cloth_pattern.dart';
import 'package:billard_cfa/shared/ui/now_card.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/watch_row.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _ui = '[Design system]/Composants';
const _home = '[Aujourd’hui]';

final _today = DateTime(2026, 10, 12);
final _posture = ExerciseRef(blockId: 'posture', number: 1);
const Map<String, ({bool proposal, String title})> _labels = {
  'posture': (title: 'Posture, visée et coup de queue', proposal: true),
};

final _sheetOption = SheetOption(
  id: SheetId('posture-1'),
  technique: 'posture',
  techniqueRank: 1,
  title: 'Posture, visée et coup de queue',
  part: 1,
  partCount: 2,
);

PlannedSessionSummary _planned({SheetId? sheet, bool withGroup = true}) =>
    PlannedSessionSummary(
      session: Session(
        id: 's1',
        title: 'Cours du mardi',
        date: DateTime(2026, 10, 14),
        audience: Audience.children,
        groupId: const GroupId('g1'),
        sheetId: sheet,
      ),
      group: withGroup
          ? Group(
              id: const GroupId('g1'),
              seasonId: const SeasonId('s'),
              name: 'Jeunes',
              audience: Audience.children,
            )
          : null,
    );

Student _student(String name) => Student.enroll(
  id: StudentId(name),
  firstName: name,
  audience: Audience.children,
  since: DateTime(2026, 9),
);

WatchedLine _line(
  String name, {
  AlertLevel alert = AlertLevel.attention,
  int failures = 3,
  int others = 0,
}) => WatchedLine(
  student: _student(name),
  watched: WatchedStudent(
    studentId: StudentId(name),
    exercise: _posture,
    alert: alert,
    consecutiveFailures: failures,
    otherAlerts: others,
  ),
);

RunningSession _running({DateTime? date}) => RunningSession(
  key: RunKey(sheetId: SheetId('posture-1')),
  step: 5,
  stepCount: 10,
  phase: SessionPhase.training,
  sheetTitle: 'Posture, visée et coup de queue',
  part: 1,
  partCount: 2,
  plannedDate: date,
);

SheetSuggestion _suggestion(SheetSuggestionKind kind) => SheetSuggestion(
  option: SheetOption(
    id: SheetId('posture-2'),
    technique: 'posture',
    techniqueRank: 1,
    title: 'Posture, visée et coup de queue',
    part: 2,
    partCount: 2,
  ),
  kind: kind,
  exerciseNumbers: const [1],
  headCovered: true,
  head: _posture,
  lastGivenOn: kind == SheetSuggestionKind.repeat
      ? DateTime(2026, 10, 5)
      : null,
);

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.all(16), child: child);

@widgetbook.UseCase(name: 'États', type: NowCard, path: _ui)
Widget buildNowCardUseCase(BuildContext context) => _pad(
  ListView(
    children: [
      NowCard(
        stateLabel: context.knobs.string(
          label: 'état',
          initialValue: 'Prochaine',
        ),
        stateIcon: Icons.event_outlined,
        title: context.knobs.string(
          label: 'titre',
          initialValue: 'Cours du mardi',
        ),
        meta: const ['mer. 14 oct. · Jeunes · Enfants · 90 min'],
        primaryLabel: 'Lancer',
        onPrimary: () {},
        secondaryLabel: 'Préparer',
        onSecondary: () {},
      ),
      const SizedBox(height: 16),
      NowCard(
        stateLabel: 'En cours',
        stateIcon: Icons.play_circle_outline,
        emphasis: SectionEmphasis.high,
        title: 'Posture, visée et coup de queue, séance 1/2',
        meta: const ['Étape 6 sur 10'],
        primaryLabel: 'Reprendre à l’étape 6',
        onPrimary: () {},
        secondaryLabel: 'Abandonner',
        onSecondary: () {},
      ),
    ],
  ),
);

@widgetbook.UseCase(name: 'Motif de tapis', type: ClothPattern, path: _ui)
Widget buildClothPatternUseCase(BuildContext context) =>
    _pad(const SizedBox(height: 96, child: ClothPattern()));

@widgetbook.UseCase(name: 'Niveaux', type: WatchRow, path: _ui)
Widget buildWatchRowUseCase(BuildContext context) => _pad(
  Column(
    children: [
      WatchRow(
        name: 'Léa',
        detail: 'Posture · exercice 1 · 3 échecs de suite',
        persistent: false,
        onTap: () {},
      ),
      WatchRow(
        name: 'Hugo',
        detail: 'Posture · exercice 1 · 5 échecs de suite',
        persistent: true,
        onTap: () {},
      ),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Prochaine séance',
  type: NextSessionCard,
  path: _home,
)
Widget buildNextSessionCardUseCase(BuildContext context) => _pad(
  NextSessionCard(
    summary: _planned(sheet: SheetId('posture-1')),
    sameDayOthers: 1,
    onPrepare: (_, _) {},
    onLaunch: (_, _, _) {},
    onOpenPlanned: () {},
  ),
);

@widgetbook.UseCase(
  name: 'Aucune séance',
  type: EmptyNextSessionCard,
  path: _home,
)
Widget buildEmptyNextSessionCardUseCase(BuildContext context) => _pad(
  EmptyNextSessionCard(
    hasClub: context.knobs.boolean(label: 'club déjà créé', initialValue: true),
    onSuggestion: () {},
    onAddStudents: () {},
  ),
);

@widgetbook.UseCase(name: 'À noter', type: ToRecordList, path: _home)
Widget buildToRecordListUseCase(BuildContext context) => _pad(
  ToRecordList(
    sessions: [_planned(sheet: SheetId('posture-1'))],
    onRecord: (_) {},
  ),
);

@widgetbook.UseCase(
  name: 'Séance en cours',
  type: RunningSessionCard,
  path: _home,
)
Widget buildRunningSessionCardUseCase(BuildContext context) => _pad(
  RunningSessionCard(
    session: _running(date: _today),
    groupName: 'Jeunes',
    onResume: () {},
    onAbandon: () {},
  ),
);

@widgetbook.UseCase(
  name: 'Autre séance commencée',
  type: RunningSessionRow,
  path: _home,
)
Widget buildRunningSessionRowUseCase(BuildContext context) =>
    _pad(RunningSessionRow(session: _running(), onResume: () {}));

@widgetbook.UseCase(
  name: 'Élèves à surveiller',
  type: WatchedStudentsCard,
  path: _home,
)
Widget buildWatchedStudentsCardUseCase(BuildContext context) => _pad(
  WatchedStudentsCard(
    watchList: WatchList(
      lines: [
        _line('Hugo', alert: AlertLevel.persistent, failures: 5, others: 1),
        _line('Léa'),
      ],
      total: 7,
      blockLabels: _labels,
    ),
    onOpenStudent: (_) {},
    onOpenAll: () {},
  ),
);

@widgetbook.UseCase(
  name: '7 derniers jours',
  type: WeekSummaryCard,
  path: _home,
)
Widget buildWeekSummaryCardUseCase(BuildContext context) => _pad(
  WeekSummaryCard(
    summary: WeekSummary(
      from: DateTime(2026, 10, 6),
      to: _today,
      passes: 14,
      validations: 2,
      sessions: 2,
    ),
  ),
);

@widgetbook.UseCase(name: 'Séance suivante', type: NextSheetCard, path: _home)
Widget buildNextSheetCardUseCase(BuildContext context) => _pad(
  NextSheetCard(
    sheet: _suggestion(
      context.knobs.object.dropdown(
        label: 'raison',
        options: SheetSuggestionKind.values,
        initialOption: SheetSuggestionKind.nextPending,
        labelBuilder: (kind) => kind.name,
      ),
    ),
    date: DateTime(2026, 10, 19),
    planning: context.knobs.object.dropdown(
      label: 'planification',
      options: NextSheetPlanning.values,
      initialOption: NextSheetPlanning.idle,
      labelBuilder: (planning) => planning.name,
    ),
    failureMessage: context.knobs.boolean(label: 'refus')
        ? 'Cette date est hors de la saison.'
        : null,
    onPlan: () {},
    onChangeDate: () {},
    onOpenPlanner: () {},
    onOpenPlanned: () {},
  ),
);

@widgetbook.UseCase(name: 'Bilan', type: SessionReviewView, path: _home)
Widget buildSessionReviewViewUseCase(BuildContext context) =>
    SingleChildScrollView(
      child: _pad(
        SessionReviewView(
          review: SessionReview(
            record: SessionRecord(
              id: const SessionId('r1'),
              groupId: const GroupId('g1'),
              seasonId: const SeasonId('s'),
              date: _today,
              audience: Audience.children,
              present: {const StudentId('Léa'), const StudentId('Hugo')},
            ),
            outcome: SessionOutcome(
              totalPasses: 5,
              totalPassed: 3,
              byExercise: [
                ExercisePasses(exercise: _posture, passes: 5, passed: 3),
              ],
              validations: [
                NewValidation(
                  studentId: const StudentId('Léa'),
                  exercise: _posture,
                ),
              ],
              unrated: const [StudentId('Hugo')],
              watched: [
                WatchedStudent(
                  studentId: const StudentId('Hugo'),
                  exercise: _posture,
                  alert: AlertLevel.attention,
                  consecutiveFailures: 3,
                  otherAlerts: 0,
                ),
              ],
            ),
            proposedDate: DateTime(2026, 10, 19),
            sheet: _sheetOption,
            students: {
              const StudentId('Léa'): _student('Léa'),
              const StudentId('Hugo'): _student('Hugo'),
            },
            blockLabels: _labels,
          ),
          next: NextSheetCard(
            sheet: _suggestion(SheetSuggestionKind.nextPending),
            date: DateTime(2026, 10, 19),
            planning: NextSheetPlanning.idle,
            onPlan: () {},
            onChangeDate: () {},
            onOpenPlanner: () {},
            onOpenPlanned: () {},
          ),
          onEnterResults: () {},
          onOpenRecord: () {},
          onOpenStudent: (_) {},
          onBackToday: () {},
        ),
      ),
    );
