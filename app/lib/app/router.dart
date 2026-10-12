import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/shell.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/open_session_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/session_date_cubit.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/exercise_sheet_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/pages/assessment/presentation/assessment_page.dart';
import 'package:billard_cfa/pages/backup/presentation/backup_page.dart';
import 'package:billard_cfa/pages/exercise_sheet/presentation/exercise_sheet_page.dart';
import 'package:billard_cfa/pages/home/presentation/home_page.dart';
import 'package:billard_cfa/pages/not_found/presentation/not_found_page.dart';
import 'package:billard_cfa/pages/record_session/presentation/record_session_page.dart';
import 'package:billard_cfa/pages/record_setup/presentation/record_setup_page.dart';
import 'package:billard_cfa/pages/session_planner/presentation/session_planner_page.dart';
import 'package:billard_cfa/pages/student_form/presentation/student_form_page.dart';
import 'package:billard_cfa/pages/student_sheet/presentation/student_sheet_page.dart';
import 'package:billard_cfa/pages/students/presentation/students_page.dart';
import 'package:billard_cfa/pages/suggested_session/presentation/suggested_session_page.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_selection_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Adresses de l'application (liens profonds par élève et par séance).
abstract final class AppRoutes {
  static const home = '/';
  static const planner = '/planner';
  static const students = '/students';
  static const newStudent = '/students/new';
  static const record = '/record';
  static const session = '/session';
  static const exercises = '/exercises';
  static const backup = '/backup';

  static String student(StudentId id) => '$students/${id.value}';

  static String editStudent(StudentId id) => '$students/${id.value}/edit';

  static String assessment(StudentId id) => '$students/${id.value}/assessment';

  static String recordSession(SessionId id) => '$record/${id.value}';

  static String exercise(ExerciseRef ref) =>
      '$exercises/${ref.blockId}/${ref.number}';
}

StudentId _studentId(GoRouterState state) =>
    StudentId(state.pathParameters['studentId']!);

GoRouter buildRouter() => GoRouter(
  errorBuilder: (context, state) =>
      NotFoundPage(onHome: () => context.go(AppRoutes.home)),
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) =>
              HomePage(onOpenPlanner: () => context.go(AppRoutes.planner)),
        ),
        GoRoute(
          path: AppRoutes.planner,
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<SessionPlannerBloc>()
                  ..add(const SessionPlannerEvent.started()),
            child: const SessionPlannerPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.students,
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<StudentsBloc>()..add(const StudentsEvent.started()),
            child: StudentsPage(
              onOpenStudent: (id) => context.go(AppRoutes.student(id)),
              onAddStudent: () => context.go(AppRoutes.newStudent),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.newStudent,
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<StudentFormBloc>()..add(const StudentFormEvent.started()),
            child: StudentFormPage(
              onSaved: (_) => context.go(AppRoutes.students),
              onBack: () => context.go(AppRoutes.students),
            ),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.students}/:studentId',
          builder: (context, state) {
            final id = _studentId(state);
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      getIt<StudentSheetBloc>()
                        ..add(StudentSheetEvent.started(studentId: id)),
                ),
                BlocProvider(
                  create: (_) =>
                      getIt<StudentRecallBloc>()
                        ..add(StudentRecallEvent.started(studentId: id)),
                ),
                BlocProvider(create: (_) => getIt<StudentErasureBloc>()),
              ],
              child: StudentSheetPage(
                onBack: () => context.go(AppRoutes.students),
                onEdit: () => context.go(AppRoutes.editStudent(id)),
                onOpenAssessment: () => context.go(AppRoutes.assessment(id)),
                onErased: () => context.go(AppRoutes.students),
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.students}/:studentId/edit',
          builder: (context, state) {
            final id = _studentId(state);
            return BlocProvider(
              create: (_) =>
                  getIt<StudentFormBloc>()
                    ..add(StudentFormEvent.started(studentId: id)),
              child: StudentFormPage(
                onSaved: (student) => context.go(AppRoutes.student(student.id)),
                onBack: () => context.go(AppRoutes.student(id)),
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.students}/:studentId/assessment',
          builder: (context, state) {
            final id = _studentId(state);
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      getIt<StudentSheetBloc>()
                        ..add(StudentSheetEvent.started(studentId: id)),
                ),
                BlocProvider(create: (_) => getIt<AssessmentBloc>()),
                BlocProvider(create: (_) => getIt<AudienceChangeBloc>()),
              ],
              child: AssessmentPage(
                onBack: () => context.go(AppRoutes.student(id)),
                today: getIt<Clock>().today(),
                readinessMinScore: getIt<RulesConfig>().readinessMinScore,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.record,
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final group = query['group'];
            final today = getIt<Clock>().today();
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      getIt<StudentsBloc>()..add(const StudentsEvent.started()),
                ),
                BlocProvider(create: (_) => getIt<OpenSessionBloc>()),
                BlocProvider(
                  create: (_) => getIt<RosterSelectionCubit>(
                    param1: group == null ? null : GroupId(group),
                  ),
                ),
                BlocProvider(
                  create: (_) => getIt<SessionDateCubit>(param1: today),
                ),
              ],
              child: RecordSetupPage(
                today: today,
                mainBlockId: query['main'],
                recallBlockId: query['recall'],
                onOpened: (id) => context.go(AppRoutes.recordSession(id)),
                onAddStudents: () => context.go(AppRoutes.newStudent),
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.record}/:sessionId',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<RecordResultsBloc>()
              ..add(
                RecordResultsEvent.started(
                  sessionId: SessionId(state.pathParameters['sessionId']!),
                ),
              ),
            child: RecordSessionPage(
              onBack: () => context.go(AppRoutes.record),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.session,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    getIt<StudentsBloc>()..add(const StudentsEvent.started()),
              ),
              BlocProvider(create: (_) => getIt<SuggestedSessionBloc>()),
              BlocProvider(create: (_) => getIt<RosterSelectionCubit>()),
            ],
            child: SuggestedSessionPage(
              onOpenSource: (ref) => context.go(AppRoutes.exercise(ref)),
              onRecord: (group, main, recall) => context.go(
                Uri(
                  path: AppRoutes.record,
                  queryParameters: {
                    'group': group.value,
                    'main': main,
                    ?(recall == null ? null : 'recall'): recall,
                  },
                ).toString(),
              ),
              onAddStudents: () => context.go(AppRoutes.newStudent),
            ),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.exercises}/:blockId/:number',
          builder: (context, state) {
            final ref = ExerciseRef.tryParse(
              state.pathParameters['blockId']!,
              state.pathParameters['number']!,
            );
            if (ref == null) {
              return NotFoundPage(onHome: () => context.go(AppRoutes.home));
            }
            return BlocProvider(
              create: (_) =>
                  getIt<ExerciseSheetBloc>()
                    ..add(ExerciseSheetEvent.started(exercise: ref)),
              child: ExerciseSheetPage(
                onBack: () => context.go(AppRoutes.session),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.backup,
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<BackupBloc>()..add(const BackupEvent.started()),
            child: BackupPage(today: getIt<Clock>().today()),
          ),
        ),
      ],
    ),
  ],
);
