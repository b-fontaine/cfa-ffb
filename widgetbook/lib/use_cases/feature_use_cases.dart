import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/ui/assessment_form.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/ui/score_selector.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/backup_reminder_banner.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/backup_view.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/features/change_audience/presentation/ui/audience_change_card.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/club_list.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/erase_student_card.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/student_form.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/features/place_student/presentation/ui/acquire_block_dialog.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/record_session_view.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/student_pass_row.dart';
import 'package:billard_cfa/features/suggest_session/domain/get_exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_recall.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/exercise_diagram_view.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/exercise_sheet_view.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/session_plan_view.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/student_recall_card.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/block_progress_list.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/exercise_curve_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/student_sheet_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _path = '[Features]';

Widget _scroll(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: child,
);

@widgetbook.UseCase(name: 'Effacement', type: EraseStudentCard, path: _path)
Widget buildEraseStudentCardUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<StudentErasureBloc>(),
    child: _scroll(
      EraseStudentCard(
        studentId: world.children.id,
        studentName: world.children.firstName,
        onErased: () {},
      ),
    ),
  ),
);

@widgetbook.UseCase(name: 'Aucune note', type: ScoreSelector, path: _path)
Widget buildScoreSelectorEmptyUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: ScoreSelector(label: 'Concentration', value: null, onChanged: (_) {}),
);

@widgetbook.UseCase(name: 'Note choisie', type: ScoreSelector, path: _path)
Widget buildScoreSelectorValueUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: ScoreSelector(label: 'Endurance', value: 3, onChanged: (_) {}),
);

@widgetbook.UseCase(name: 'Formulaire', type: AssessmentForm, path: _path)
Widget buildAssessmentFormUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<AssessmentBloc>(),
    child: _scroll(
      AssessmentForm(studentId: world.children.id, readinessMinScore: 3),
    ),
  ),
);

@widgetbook.UseCase(name: 'Ajout', type: StudentForm, path: _path)
Widget buildStudentFormUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<StudentFormBloc>()..add(const StudentFormEvent.started()),
    child: _scroll(const StudentForm()),
  ),
);

@widgetbook.UseCase(name: 'Édition', type: StudentForm, path: _path)
Widget buildStudentFormEditUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<StudentFormBloc>()
          ..add(StudentFormEvent.started(studentId: world.children.id)),
    child: _scroll(const StudentForm()),
  ),
);

@widgetbook.UseCase(name: 'Club', type: ClubList, path: _path)
Widget buildClubListUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<GetClubOverview>()(today: world.today),
  builder: (context, world, club) =>
      _scroll(ClubList(club: club, onOpenStudent: (_) {})),
);

@widgetbook.UseCase(name: 'Sans retour', type: StudentPassRow, path: _path)
Widget buildStudentPassRowUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => _scroll(
    StudentPassRow(
      studentName: world.children.firstName,
      spec: world.catalogue.exercise(PreviewWorld.struggling)!,
      passes: const [],
      passedCount: 0,
      maxPasses: 2,
      passesRequired: 5,
      onSubmit: (_, _) {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Reprise après positionnement',
  type: StudentPassRow,
  path: _path,
)
Widget buildStudentPassRowResumedUseCase(BuildContext context) => WorldScope(
  builder: (context, world) {
    final spec = world.catalogue.exercise(PreviewWorld.validated)!;
    final attempt = ExerciseAttempt(
      id: const AttemptId('apercu-passage'),
      studentId: world.children.id,
      sessionId: const SessionId('apercu-seance'),
      exercise: spec.ref,
      date: world.today,
      passIndex: 1,
      potted: spec.rate.successes,
      total: spec.rate.attempts,
    );
    return _scroll(
      StudentPassRow(
        studentName: world.children.firstName,
        spec: spec,
        passes: [attempt],
        passedCount: 1,
        maxPasses: 2,
        passesRequired: 5,
        onSubmit: (_, _) {},
        feedback: RecordedAttempt(
          attempt: attempt,
          result: ExerciseResult.derive(
            studentId: world.children.id,
            exercise: spec.ref,
            rate: spec.rate,
            attempts: [attempt],
            config: RulesConfig(),
          ),
          passed: true,
          justValidated: false,
          resumedFromPlacement: true,
          nextExercise: spec.ref,
        ),
      ),
    );
  },
);

@widgetbook.UseCase(
  name: 'Liste compacte (téléphone)',
  type: StudentPassRow,
  path: _path,
)
Widget buildStudentPassRowCompactUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MediaQuery(
    data: MediaQuery.of(context).copyWith(size: const Size(390, 844)),
    child: _scroll(
      StudentPassRow(
        studentName: world.children.firstName,
        spec: world.catalogue.exercise(PreviewWorld.struggling)!,
        passes: const [],
        passedCount: 2,
        maxPasses: 2,
        passesRequired: 5,
        onSubmit: (_, _) {},
      ),
    ),
  ),
);

@widgetbook.UseCase(name: 'Limite atteinte', type: StudentPassRow, path: _path)
Widget buildStudentPassRowLimitUseCase(BuildContext context) => WorldScope(
  builder: (context, world) {
    final spec = world.catalogue.exercise(PreviewWorld.validated)!;
    ExerciseAttempt pass(int index) => ExerciseAttempt(
      id: AttemptId('apercu-passage-$index'),
      studentId: world.children.id,
      sessionId: const SessionId('apercu-seance'),
      exercise: spec.ref,
      date: world.today,
      passIndex: index,
      potted: spec.rate.successes,
      total: spec.rate.attempts,
    );
    return _scroll(
      StudentPassRow(
        studentName: world.children.firstName,
        spec: spec,
        passes: [pass(1), pass(2)],
        passedCount: 2,
        maxPasses: 2,
        passesRequired: 5,
        onSubmit: (_, _) {},
        refusedMessage: 'Deux passages au maximum par séance.',
      ),
    );
  },
);
@widgetbook.UseCase(
  name: 'Séance ouverte',
  type: RecordSessionView,
  path: _path,
)
Widget buildRecordSessionViewUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<RecordResultsBloc>()
          ..add(RecordResultsEvent.started(sessionId: world.sessionId)),
    child: BlocBuilder<RecordResultsBloc, RecordResultsState>(
      builder: (context, state) => state.status == RecordStatus.ready
          ? _scroll(RecordSessionView(state: state))
          : const Center(child: CircularProgressIndicator()),
    ),
  ),
);

@widgetbook.UseCase(name: 'Fiche', type: ExerciseSheetView, path: _path)
Widget buildExerciseSheetViewUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<GetExerciseSheet>()(PreviewWorld.validated),
  builder: (context, world, sheet) => _scroll(ExerciseSheetView(sheet: sheet)),
);

@widgetbook.UseCase(name: 'Un schéma', type: ExerciseDiagramView, path: _path)
Widget buildExerciseDiagramViewUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<GetExerciseSheet>()(PreviewWorld.validated),
  builder: (context, world, sheet) =>
      _scroll(ExerciseDiagramView(sheet: sheet)),
);

@widgetbook.UseCase(
  name: 'Deux schémas (rejet naturel)',
  type: ExerciseDiagramView,
  path: _path,
)
Widget buildExerciseDiagramViewTwiceUseCase(BuildContext context) =>
    LoadedScope(
      load: (world) => getIt<GetExerciseSheet>()(
        ExerciseRef(blockId: 'rejet-naturel', number: 1),
      ),
      builder: (context, world, sheet) =>
          _scroll(ExerciseDiagramView(sheet: sheet)),
    );

@widgetbook.UseCase(
  name: 'Aucun schéma',
  type: ExerciseDiagramView,
  path: _path,
)
Widget buildExerciseDiagramViewMissingUseCase(BuildContext context) =>
    LoadedScope(
      load: (world) => getIt<GetExerciseSheet>()(PreviewWorld.validated),
      builder: (context, world, sheet) => _scroll(
        ExerciseDiagramView(sheet: sheet.copyWith(diagrams: const [])),
      ),
    );

@widgetbook.UseCase(
  name: 'Schémas illisibles',
  type: ExerciseDiagramView,
  path: _path,
)
Widget buildExerciseDiagramViewUnreadableUseCase(BuildContext context) =>
    LoadedScope(
      load: (world) => getIt<GetExerciseSheet>()(PreviewWorld.validated),
      builder: (context, world, sheet) => _scroll(
        ExerciseDiagramView(
          sheet: sheet.copyWith(diagrams: const [], diagramsUnreadable: true),
        ),
      ),
    );

@widgetbook.UseCase(
  name: 'Notion à rappeler',
  type: StudentRecallCard,
  path: _path,
)
Widget buildStudentRecallCardUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<SuggestRecall>()(world.children.id),
  builder: (context, world, advice) =>
      _scroll(StudentRecallCard(advice: advice)),
);

@widgetbook.UseCase(
  name: 'Rien à rappeler',
  type: StudentRecallCard,
  path: _path,
)
Widget buildStudentRecallCardEmptyUseCase(BuildContext context) =>
    _scroll(const StudentRecallCard(advice: null));

@widgetbook.UseCase(name: 'Séance suggérée', type: SessionPlanView, path: _path)
Widget buildSessionPlanViewUseCase(BuildContext context) =>
    _sessionPlanView(sheetKept: true);

@widgetbook.UseCase(
  name: 'Séance suggérée sans séance du catalogue',
  type: SessionPlanView,
  path: _path,
)
Widget buildSessionPlanViewWithoutSheetUseCase(BuildContext context) =>
    _sessionPlanView(sheetKept: false);

Widget _sessionPlanView({required bool sheetKept}) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<SuggestedSessionBloc>()
      ..add(
        SuggestedSessionEvent.requested(
          groupId: world.childrenGroup,
          expectedStudents: {world.children.id},
        ),
      ),
    child: BlocBuilder<SuggestedSessionBloc, SuggestedSessionState>(
      builder: (context, state) {
        final plan = state.plan;
        if (plan == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _scroll(
          SessionPlanView(
            plan: sheetKept ? plan : plan.copyWith(sheet: null),
            exercises: state.exercises,
            recall: state.recall,
            onOpenSource: (_) {},
            onRecord: () {},
            onOpenSheet: (_) {},
            onLaunch: (_) {},
            onPlan: (_) {},
          ),
        );
      },
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Changement de public',
  type: AudienceChangeCard,
  path: _path,
)
Widget buildAudienceChangeCardUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<AudienceChangeBloc>(),
    child: _scroll(
      AudienceChangeCard(student: world.children, today: world.today),
    ),
  ),
);

@widgetbook.UseCase(name: 'Fiche élève', type: StudentSheetView, path: _path)
Widget buildStudentSheetViewUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<GetStudentSheet>()(world.children.id),
  builder: (context, world, sheet) => _scroll(StudentSheetView(sheet: sheet)),
);

@widgetbook.UseCase(
  name: 'Progression par bloc',
  type: BlockProgressList,
  path: _path,
)
Widget buildBlockProgressListUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<GetStudentSheet>()(world.children.id),
  builder: (context, world, sheet) => _scroll(
    BlockProgressList(
      sheet: sheet,
      onMarkAcquired: (_) {},
      onRevokeAcquired: (_) {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Marquer le bloc acquis',
  type: AcquireBlockDialog,
  path: _path,
)
Widget buildAcquireBlockDialogUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<PlacementBloc>(),
    child: AcquireBlockDialog(
      studentId: world.children.id,
      blockId: 'posture',
      blockTitle: 'Posture, visée et coup de queue',
      exerciseCount: 4,
      today: world.today,
    ),
  ),
);

@widgetbook.UseCase(name: 'Courbe', type: ExerciseCurveCard, path: _path)
Widget buildExerciseCurveCardUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<GetStudentSheet>()(world.children.id),
  builder: (context, world, sheet) => _scroll(
    ExerciseCurveCard(
      series: sheet.series.last,
      title: StudentSheetView.exerciseTitle(
        AppLocalizations.of(context),
        sheet,
        sheet.series.last.exercise,
      ),
      passesRequired: sheet.passesRequired,
    ),
  ),
);

@widgetbook.UseCase(name: 'Sauvegarde', type: BackupView, path: _path)
Widget buildBackupViewUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<BackupBloc>()..add(const BackupEvent.started()),
    child: _scroll(const BackupView(fileName: 'sauvegarde-2026-10-12.json')),
  ),
);

@widgetbook.UseCase(
  name: 'Rappel de sauvegarde',
  type: BackupReminderBanner,
  path: _path,
)
Widget buildBackupReminderBannerUseCase(BuildContext context) =>
    BackupReminderBanner(
      reminder: switch (context.knobs.object.dropdown<String>(
        label: 'rappel',
        options: const ['jamais sauvegardé', 'ancienne', 'nouveaux passages'],
      )) {
        'ancienne' => const StaleBackup(34),
        'nouveaux passages' => const NewPassesSinceBackup(12),
        _ => const NeverBackedUp(),
      },
      onBackup: () {},
    );
