import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/shell.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/open_session_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/recorded_sessions_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/session_date_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_presentation_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/exercise_sheet_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/pages/assessment/presentation/assessment_page.dart';
import 'package:billard_cfa/pages/backup/presentation/backup_page.dart';
import 'package:billard_cfa/pages/exercise_sheet/presentation/exercise_sheet_page.dart';
import 'package:billard_cfa/pages/home/presentation/home_page.dart';
import 'package:billard_cfa/pages/not_found/presentation/not_found_page.dart';
import 'package:billard_cfa/pages/record_history/presentation/record_history_page.dart';
import 'package:billard_cfa/pages/record_session/presentation/record_session_page.dart';
import 'package:billard_cfa/pages/record_setup/presentation/record_setup_page.dart';
import 'package:billard_cfa/pages/session_planner/presentation/session_planner_page.dart';
import 'package:billard_cfa/pages/sheet_catalogue/presentation/sheet_catalogue_page.dart';
import 'package:billard_cfa/pages/sheet_detail/presentation/sheet_detail_page.dart';
import 'package:billard_cfa/pages/sheet_guide/presentation/sheet_guide_page.dart';
import 'package:billard_cfa/pages/sheet_presentation/presentation/sheet_presentation_page.dart';
import 'package:billard_cfa/pages/student_form/presentation/student_form_page.dart';
import 'package:billard_cfa/pages/student_sheet/presentation/student_sheet_page.dart';
import 'package:billard_cfa/pages/students/presentation/students_page.dart';
import 'package:billard_cfa/pages/suggested_session/presentation/suggested_session_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
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

  /// Ouverture d'une nouvelle saisie (groupe, présents, date) ; `/record`
  /// est l'historique des séances saisies (ADR 0006).
  static const newRecord = '/record/new';
  static const session = '/session';
  static const exercises = '/exercises';
  static const backup = '/backup';
  static const catalogue = '/catalogue';

  /// Segments des sous-pages d'une séance du catalogue : chemin des routes ET
  /// des constructeurs d'adresse.
  static const guideSegment = 'guide';
  static const presentationSegment = 'presentation';

  /// Adresse de [path] avec ses paramètres non vides (jamais de `?` seul).
  static String _url(String path, Map<String, String> query) =>
      Uri(path: path, queryParameters: query.isEmpty ? null : query).toString();

  /// Jour en paramètre d'adresse (`2026-10-13`), relu par `_dateParam`.
  static String _dateQuery(DateTime date) =>
      date.toIso8601String().substring(0, 10);

  /// Planificateur, séance du catalogue (et public) présélectionnés.
  static String plan(SheetId id, {Audience? audience}) =>
      _url(planner, {'sheet': id.value, 'audience': ?audience?.name});

  static String student(StudentId id) => '$students/${id.value}';

  static String editStudent(StudentId id) => '$students/${id.value}/edit';

  static String assessment(StudentId id) => '$students/${id.value}/assessment';

  /// Saisie d'une séance ouverte ; [exercise] présélectionne un exercice du
  /// bloc principal et [from] est l'adresse à retrouver au retour (séance
  /// guidée).
  static String recordSession(SessionId id, {int? exercise, String? from}) =>
      _url('$record/${id.value}', {
        'exercise': ?exercise?.toString(),
        'from': ?from,
      });

  /// Ouverture de la saisie depuis la séance guidée : bloc de l'exercice,
  /// bloc du rappel de résultats, exercice à présélectionner, séance du
  /// catalogue notée ([sheet], ADR 0007) et retour à [from]. [group],
  /// [absent] et [date] reprennent le choix de la saisie précédente ou la
  /// séance planifiée (sans eux, le groupe se choisit à la saisie).
  static String recordFromGuide({
    required ExerciseRef exercise,
    required String from,
    String? recall,
    SheetId? sheet,
    GroupId? group,
    Set<StudentId> absent = const {},
    DateTime? date,
  }) => _url(newRecord, {
    'main': exercise.blockId,
    'recall': ?recall,
    'exercise': '${exercise.number}',
    'sheet': ?sheet?.value,
    'from': from,
    'group': ?group?.value,
    if (absent.isNotEmpty) 'absent': absent.map((id) => id.value).join(','),
    'date': ?(date == null ? null : _dateQuery(date)),
  });

  /// Ouverture de la saisie d'une séance planifiée : groupe et date de la
  /// séance, séance du catalogue suivie si elle est connue (ADR 0007).
  static String recordFromPlan({
    required GroupId group,
    required DateTime date,
    SheetId? sheet,
  }) => _url(newRecord, {
    'group': group.value,
    'date': _dateQuery(date),
    'sheet': ?sheet?.value,
  });

  /// Séance guidée d'une séance du catalogue. [audience] absent : public de
  /// la séance planifiée [session], sinon les enfants ; [step] : étape à
  /// partir de 0.
  static String guide(
    SheetId id, {
    Audience? audience,
    String? session,
    int? step,
  }) => _url('$catalogue/${id.value}/$guideSegment', {
    'audience': ?audience?.name,
    'session': ?session,
    'step': ?step?.toString(),
  });

  /// Présentation plein écran d'une étape de la séance guidée.
  static String presentation(
    SheetId id, {
    Audience? audience,
    String? session,
    int? step,
  }) => _url('$catalogue/${id.value}/$presentationSegment', {
    'audience': ?audience?.name,
    'session': ?session,
    'step': ?step?.toString(),
  });

  static String exercise(ExerciseRef ref) =>
      '$exercises/${ref.blockId}/${ref.number}';

  /// Séance du catalogue ; [audience] présélectionne le public affiché et
  /// [fromPlanner] fait revenir au planificateur plutôt qu'au catalogue.
  static String sheet(
    SheetId id, {
    Audience? audience,
    bool fromPlanner = false,
  }) {
    return _url('$catalogue/${id.value}', {
      'audience': ?audience?.name,
      if (fromPlanner) 'from': plannerOrigin,
    });
  }

  /// Valeur de `from` d'une séance ouverte depuis le planificateur.
  static const plannerOrigin = 'planner';
}

/// Adresse de retour à une séance guidée : intérieure à l'application et
/// limitée au catalogue (jamais une adresse extérieure).
String? _guideReturn(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('${AppRoutes.catalogue}/')) {
    return null;
  }
  return uri.toString();
}

Audience? _audienceParam(String? raw) => Audience.values.asNameMap()[raw];

/// Absents d'une saisie guidée (`absent=a,b`) ; les identifiants vides sont
/// ignorés.
Set<StudentId> _absentParam(String? raw) => {
  for (final id in (raw ?? '').split(','))
    if (id.trim().isNotEmpty) StudentId(id.trim()),
};

/// Date d'une saisie guidée (`date=2026-10-13`), `null` si illisible.
DateTime? _dateParam(String? raw) {
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

/// Clé de séance guidée de la séance [id] et des paramètres [query] de son
/// adresse (public, séance planifiée).
RunKey _runKey(SheetId id, Map<String, String> query) => RunKey(
  sheetId: id,
  audience: _audienceParam(query['audience']),
  sessionId: _nonBlank(query['session']),
);

/// Clé de la séance guidée désignée par [guideUrl] (adresse de retour d'une
/// saisie), `null` si ce n'est pas l'adresse d'un guide.
RunKey? _guideKey(String guideUrl) {
  final uri = Uri.tryParse(guideUrl);
  final segments = uri?.pathSegments ?? const <String>[];
  if (uri == null ||
      segments.length != 3 ||
      '/${segments[0]}' != AppRoutes.catalogue ||
      segments[2] != AppRoutes.guideSegment) {
    return null;
  }
  final id = SheetId.tryParse(segments[1]);
  return id == null ? null : _runKey(id, uri.queryParameters);
}

String? _nonBlank(String? raw) =>
    raw == null || raw.trim().isEmpty ? null : raw;

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
          builder: (context, state) {
            final query = state.uri.queryParameters;
            return BlocProvider(
              create: (_) => getIt<SessionPlannerBloc>()
                ..add(
                  SessionPlannerEvent.started(
                    today: getIt<Clock>().today(),
                    sheetId: SheetId.tryParse(query['sheet']),
                    audience:
                        _audienceParam(query['audience']) ?? Audience.children,
                  ),
                ),
              child: SessionPlannerPage(
                onOpenSheet: (id, audience) => context.go(
                  AppRoutes.sheet(id, audience: audience, fromPlanner: true),
                ),
                onChooseSheet: () => context.go(AppRoutes.catalogue),
                onLaunchSheet: (id, audience, sessionId) => context.go(
                  AppRoutes.guide(id, audience: audience, session: sessionId),
                ),
                onRecord: (group, date, sheet) => context.go(
                  AppRoutes.recordFromPlan(
                    group: group,
                    date: date,
                    sheet: sheet,
                  ),
                ),
                onOpenRecord: (id) => context.go(AppRoutes.recordSession(id)),
              ),
            );
          },
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
                BlocProvider(create: (_) => getIt<PlacementBloc>()),
              ],
              child: StudentSheetPage(
                today: getIt<Clock>().today,
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
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<RecordedSessionsBloc>()
                  ..add(const RecordedSessionsEvent.started()),
            child: RecordHistoryPage(
              onOpenSession: (id) => context.go(AppRoutes.recordSession(id)),
              onNewSession: () => context.go(AppRoutes.newRecord),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.newRecord,
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final group = query['group'];
            final absent = _absentParam(query['absent']);
            final exercise = int.tryParse(query['exercise'] ?? '');
            final from = _guideReturn(query['from']);
            final sheet = SheetId.tryParse(query['sheet']);
            final today = getIt<Clock>().today();
            final date = _dateParam(query['date']) ?? today;
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
                    param2: absent,
                  ),
                ),
                BlocProvider(
                  create: (_) => getIt<SessionDateCubit>(param1: date),
                ),
              ],
              child: RecordSetupPage(
                today: today,
                mainBlockId: query['main'],
                recallBlockId: query['recall'],
                sheetId: sheet,
                onOpened: (opened) {
                  // La séance guidée retient le choix : l'exercice suivant
                  // ne redemande ni groupe, ni présents, ni date.
                  final key = from == null ? null : _guideKey(from);
                  if (key != null) {
                    getIt<RunSheetSessions>()
                        .of(key)
                        .recordChosen(
                          group: opened.group,
                          date: opened.date,
                          absent: opened.absent,
                        );
                  }
                  context.go(
                    AppRoutes.recordSession(
                      opened.id,
                      exercise: exercise,
                      from: from,
                    ),
                  );
                },
                onAddStudents: () => context.go(AppRoutes.newStudent),
                onBackToGuide: from == null ? null : () => context.go(from),
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.record}/:sessionId',
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final from = _guideReturn(query['from']);
            return BlocProvider(
              create: (_) => getIt<RecordResultsBloc>()
                ..add(
                  RecordResultsEvent.started(
                    sessionId: SessionId(state.pathParameters['sessionId']!),
                    initialExercise: int.tryParse(query['exercise'] ?? ''),
                  ),
                ),
              child: RecordSessionPage(
                onBack: () => context.go(from ?? AppRoutes.record),
                fromGuide: from != null,
              ),
            );
          },
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
                  path: AppRoutes.newRecord,
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
          path: AppRoutes.catalogue,
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<SheetCatalogueBloc>()
                  ..add(const SheetCatalogueEvent.started()),
            child: SheetCataloguePage(
              onOpenSheet: (id) => context.go(AppRoutes.sheet(id)),
              onOpenSuggestion: () => context.go(AppRoutes.session),
            ),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.catalogue}/:sheetId',
          builder: (context, state) {
            final id = SheetId.tryParse(state.pathParameters['sheetId']);
            if (id == null) {
              return NotFoundPage(onHome: () => context.go(AppRoutes.home));
            }
            final audience =
                _audienceParam(state.uri.queryParameters['audience']) ??
                Audience.children;
            return BlocProvider(
              create: (_) => getIt<SheetDetailBloc>()
                ..add(
                  SheetDetailEvent.started(sheetId: id, audience: audience),
                ),
              child: SheetDetailPage(
                fromPlanner:
                    state.uri.queryParameters['from'] ==
                    AppRoutes.plannerOrigin,
                onBack: () => context.go(
                  state.uri.queryParameters['from'] == AppRoutes.plannerOrigin
                      ? AppRoutes.planner
                      : AppRoutes.catalogue,
                ),
                onHome: () => context.go(AppRoutes.home),
                onPlan: (audience) =>
                    context.go(AppRoutes.plan(id, audience: audience)),
                onLaunch: (audience) =>
                    context.go(AppRoutes.guide(id, audience: audience)),
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.catalogue}/:sheetId/${AppRoutes.guideSegment}',
          builder: (context, state) {
            final id = SheetId.tryParse(state.pathParameters['sheetId']);
            if (id == null) {
              return NotFoundPage(onHome: () => context.go(AppRoutes.home));
            }
            final query = state.uri.queryParameters;
            final key = _runKey(id, query);
            final sessions = getIt<RunSheetSessions>();
            final cubit = sessions.of(key);
            unawaited(
              cubit.syncFromRoute(step: int.tryParse(query['step'] ?? '')),
            );
            String guide(int? step) => AppRoutes.guide(
              id,
              audience: key.audience,
              session: key.sessionId,
              step: step,
            );
            // Retour et fin : la séance planifiée d'où le guide a été lancé,
            // sinon la séance du catalogue.
            final fromPlanner = key.sessionId != null;
            String origin() => fromPlanner
                ? AppRoutes.planner
                : AppRoutes.sheet(id, audience: key.audience);
            return BlocProvider.value(
              value: cubit,
              child: SheetGuidePage(
                fromPlanner: fromPlanner,
                onBack: () => context.go(origin()),
                onHome: () => context.go(AppRoutes.home),
                onShow: (step) => context.push(
                  AppRoutes.presentation(
                    id,
                    audience: key.audience,
                    session: key.sessionId,
                    step: step,
                  ),
                ),
                onRecord: (exercise, recall, step) {
                  final defaults = cubit.state.recordDefaults;
                  context.go(
                    AppRoutes.recordFromGuide(
                      exercise: exercise,
                      recall: recall,
                      sheet: id,
                      from: guide(step),
                      group: defaults.group,
                      absent: defaults.absent,
                      date: defaults.date,
                    ),
                  );
                },
                onFinish: () {
                  context.go(origin());
                  unawaited(sessions.release(key));
                },
                onStepChanged: (step) => context.go(guide(step)),
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
    GoRoute(
      path: '${AppRoutes.catalogue}/:sheetId/${AppRoutes.presentationSegment}',
      builder: (context, state) {
        final id = SheetId.tryParse(state.pathParameters['sheetId']);
        if (id == null) {
          return NotFoundPage(onHome: () => context.go(AppRoutes.home));
        }
        final query = state.uri.queryParameters;
        final audience = _audienceParam(query['audience']);
        final session = _nonBlank(query['session']);
        return BlocProvider(
          create: (_) {
            final cubit = getIt<RunPresentationCubit>();
            unawaited(
              cubit.started(
                sheetId: id,
                audience: audience,
                sessionId: session,
                step: int.tryParse(query['step'] ?? '') ?? 0,
              ),
            );
            return cubit;
          },
          child: SheetPresentationPage(
            onClose: (step) => context.go(
              AppRoutes.guide(
                id,
                audience: audience,
                session: session,
                step: step,
              ),
            ),
            onHome: () => context.go(AppRoutes.home),
          ),
        );
      },
    ),
  ],
);
