import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/record_screens.dart';
import 'package:billard_cfa/app/record_sheet.dart';
import 'package:billard_cfa/app/shell.dart';
import 'package:billard_cfa/features/acknowledge_alert/presentation/bloc/acknowledgement_bloc.dart';
import 'package:billard_cfa/features/app_update/presentation/bloc/app_update_cubit.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_reminder_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/backup_reminder_banner.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/closable_season_cubit.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/features/close_season/presentation/ui/closable_season_section.dart';
import 'package:billard_cfa/features/manage_groups/presentation/bloc/manage_groups_cubit.dart';
import 'package:billard_cfa/features/manage_groups/presentation/bloc/move_student_cubit.dart';
import 'package:billard_cfa/features/manage_settings/presentation/bloc/settings_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/plan_next_session_cubit.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/upcoming_sessions_cubit.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/recorded_sessions_bloc.dart';
import 'package:billard_cfa/features/review_session/presentation/bloc/session_review_bloc.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_presentation_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_sessions_cubit.dart';
import 'package:billard_cfa/features/student_showcase/presentation/bloc/showcase_cubit.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/exercise_sheet_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/group_journey_cubit.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/next_sheet_cubit.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/features/track_group/presentation/bloc/group_alerts_cubit.dart';
import 'package:billard_cfa/features/track_group/presentation/bloc/group_overview_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/watched_students_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/week_summary_cubit.dart';
import 'package:billard_cfa/features/track_seasons/presentation/bloc/season_archives_cubit.dart';
import 'package:billard_cfa/pages/assessment/presentation/assessment_page.dart';
import 'package:billard_cfa/pages/backup/presentation/backup_page.dart';
import 'package:billard_cfa/pages/exercise_sheet/presentation/exercise_sheet_page.dart';
import 'package:billard_cfa/pages/group_overview/presentation/group_overview_page.dart';
import 'package:billard_cfa/pages/home/presentation/home_page.dart';
import 'package:billard_cfa/pages/more/presentation/more_page.dart';
import 'package:billard_cfa/pages/not_found/presentation/not_found_page.dart';
import 'package:billard_cfa/pages/record_history/presentation/record_history_page.dart';
import 'package:billard_cfa/pages/season_archive/presentation/season_archive_page.dart';
import 'package:billard_cfa/pages/season_closure/presentation/season_closure_page.dart';
import 'package:billard_cfa/pages/session_planner/presentation/session_planner_page.dart';
import 'package:billard_cfa/pages/session_review/presentation/session_review_page.dart';
import 'package:billard_cfa/pages/settings/presentation/settings_page.dart';
import 'package:billard_cfa/pages/sheet_catalogue/presentation/sheet_catalogue_page.dart';
import 'package:billard_cfa/pages/sheet_detail/presentation/sheet_detail_page.dart';
import 'package:billard_cfa/pages/sheet_guide/presentation/sheet_guide_page.dart';
import 'package:billard_cfa/pages/sheet_presentation/presentation/sheet_presentation_page.dart';
import 'package:billard_cfa/pages/student_form/presentation/student_form_page.dart';
import 'package:billard_cfa/pages/student_sheet/presentation/student_sheet_page.dart';
import 'package:billard_cfa/pages/student_showcase/presentation/student_showcase_page.dart';
import 'package:billard_cfa/pages/students/presentation/students_page.dart';
import 'package:billard_cfa/pages/suggested_session/presentation/suggested_session_page.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
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
  static const more = '/more';
  static const backup = '/backup';
  static const settings = '/settings';
  static const seasons = '/seasons';
  static const catalogue = '/catalogue';

  /// Segments des sous-pages d'une séance du catalogue : chemin des routes ET
  /// des constructeurs d'adresse.
  static const guideSegment = 'guide';

  /// Segments des sous-pages d'un élève et d'un groupe : vue « à montrer à
  /// l'élève » (hors du cadre de navigation) et grille d'un groupe.
  static const showcaseSegment = 'show';
  static const groupsSegment = 'groups';
  static const presentationSegment = 'presentation';

  /// Segment de l'assistant de clôture d'une saison.
  static const closeSegment = 'close';

  /// Adresse de [path] avec ses paramètres non vides (jamais de `?` seul).
  static String _url(String path, Map<String, String> query) =>
      Uri(path: path, queryParameters: query.isEmpty ? null : query).toString();

  /// Jour en paramètre d'adresse (`2026-10-13`), relu par `_dateParam`.
  static String _dateQuery(DateTime date) =>
      date.toIso8601String().substring(0, 10);

  /// Planificateur, séance du catalogue (et public) présélectionnés.
  /// Sans [id] (notion sans séance du catalogue), le planificateur s'ouvre
  /// sans séance présélectionnée.
  /// [group] présélectionne le groupe choisi dans le catalogue.
  static String plan(SheetId? id, {Audience? audience, GroupId? group}) => _url(
    planner,
    {'sheet': ?id?.value, 'audience': ?audience?.name, 'group': ?group?.value},
  );

  /// L'assistant de clôture d'une saison (hors du cadre de navigation).
  static String closeSeason(SeasonId id) =>
      '$seasons/${id.value}/$closeSegment';

  static String student(StudentId id) => '$students/${id.value}';

  static String editStudent(StudentId id) => '$students/${id.value}/edit';

  /// La vue « à montrer à l'élève » : prénom et parcours seulement.
  static String showcase(StudentId id) =>
      '$students/${id.value}/$showcaseSegment';

  /// La grille d'un groupe (carte de chaleur technique × élève).
  static String studentGroup(GroupId id) =>
      '$students/$groupsSegment/${id.value}';

  static String assessment(StudentId id) => '$students/${id.value}/assessment';

  /// Saisie d'une séance ouverte ; [exercise] présélectionne un exercice du
  /// bloc principal et [from] est l'adresse à retrouver au retour (séance
  /// guidée).
  static String recordSession(
    SessionId id, {
    int? exercise,
    String? exerciseBlock,
    String? from,
  }) => _url('$record/${id.value}', {
    'exercise': ?exercise?.toString(),
    'exercise_block': ?exerciseBlock,
    'from': ?from,
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

  /// Ouverture de la saisie depuis la séance suggérée : groupe, notion
  /// principale, rappel et séance du catalogue proposée ([sheet], nul pour
  /// une notion sans séance, ADR 0009).
  static String recordFromSuggestion({
    required GroupId group,
    required String main,
    String? recall,
    SheetId? sheet,
  }) => _url(newRecord, {
    'group': group.value,
    'main': main,
    'recall': ?recall,
    'sheet': ?sheet?.value,
  });

  /// Séance guidée d'une séance du catalogue. [audience] absent : public de
  /// la séance planifiée [session], sinon les enfants ; [step] : étape à
  /// partir de 0 ; [group] : groupe pour lequel on mène, choisi dans le
  /// catalogue ou pour la séance suggérée, proposé à la saisie des résultats.
  /// [from] est l'origine directe du lancement (Aujourd'hui, Planifiées,
  /// Suggestion), [via] l'origine du détail quand le guide est lancé depuis lui
  /// : le retour y mène (voir [guideBackTarget]). [mode] impose le mode du
  /// guide (absent : celui que la clé de la séance détermine).
  static String guide(
    SheetId id, {
    Audience? audience,
    String? session,
    int? step,
    GroupId? group,
    SheetOrigin? from,
    SheetOrigin? via,
    RunMode? mode,
  }) => _url('$catalogue/${id.value}/$guideSegment', {
    'audience': ?audience?.name,
    'session': ?session,
    'step': ?step?.toString(),
    'group': ?group?.value,
    if (from != null && from != SheetOrigin.catalogue) 'from': from.name,
    if (via != null && via != SheetOrigin.catalogue) 'via': via.name,
    'mode': ?mode?.name,
  });

  /// Présentation plein écran d'une étape de la séance guidée.
  ///
  /// Porte les mêmes paramètres que [guide] ([group], [from], [via], [mode]) :
  /// sa fermeture retrouve le guide tel qu'il était.
  static String presentation(
    SheetId id, {
    Audience? audience,
    String? session,
    int? step,
    GroupId? group,
    SheetOrigin? from,
    SheetOrigin? via,
    RunMode? mode,
  }) => _url('$catalogue/${id.value}/$presentationSegment', {
    'audience': ?audience?.name,
    'session': ?session,
    'step': ?step?.toString(),
    'group': ?group?.value,
    if (from != null && from != SheetOrigin.catalogue) 'from': from.name,
    if (via != null && via != SheetOrigin.catalogue) 'via': via.name,
    'mode': ?mode?.name,
  });

  static String exercise(ExerciseRef ref) =>
      '$exercises/${ref.blockId}/${ref.number}';

  /// Le catalogue, avec le groupe choisi (marqueurs de parcours) restauré au
  /// retour d'une séance.
  static String catalogueFor(GroupId? group) =>
      _url(catalogue, {'group': ?group?.value});

  /// Séance du catalogue ; [audience] présélectionne le public affiché,
  /// [origin] dit où le retour mène (le catalogue, absent de l'adresse) et
  /// [group] est le groupe choisi dans le catalogue, restauré au retour.
  static String sheet(
    SheetId id, {
    Audience? audience,
    SheetOrigin origin = SheetOrigin.catalogue,
    GroupId? group,
  }) {
    return _url('$catalogue/${id.value}', {
      'audience': ?audience?.name,
      if (origin != SheetOrigin.catalogue) 'from': origin.name,
      'group': ?group?.value,
    });
  }

  /// Bilan de fin de séance d'une saisie (vue d'une saisie persistée : il se
  /// partage par son adresse et survit à un rechargement).
  static String review(SessionId id) => '$record/${id.value}/$reviewSegment';

  static const reviewSegment = 'review';
}

/// D'où une séance du catalogue est ouverte (« Préparer ») : le retour y
/// mène. Paramètre d'adresse `from`, jamais un état en mémoire : il survit à un
/// rechargement et aux liens profonds.
enum SheetOrigin {
  /// Le catalogue (valeur par défaut, absente de l'adresse).
  catalogue,

  /// Les séances planifiées (`from=planner`).
  planner,

  /// L'accueil « Aujourd'hui » (`from=today`).
  today,

  /// La séance suggérée (`from=suggestion`).
  suggestion;

  /// L'origine d'une valeur d'adresse ; toute valeur absente ou inconnue
  /// retombe sur [catalogue] (jamais une adresse libre).
  static SheetOrigin parse(String? raw) => SheetOrigin.values.firstWhere(
    (origin) => origin.name == raw,
    orElse: () => SheetOrigin.catalogue,
  );

  /// L'origine d'une valeur d'adresse, `null` si elle est absente ou inconnue
  /// (le guide distingue « pas d'origine » de « le catalogue »).
  static SheetOrigin? tryParse(String? raw) {
    for (final origin in values) {
      if (origin.name == raw) return origin;
    }
    return null;
  }
}

/// Adresse où mène le retour (et la fin sans bilan) d'une séance guidée.
///
/// L'origine directe [from] l'emporte : Planifiées, Aujourd'hui, Suggestion.
/// Sans [from], une séance planifiée [session] ramène à Planifiées (liens
/// existants) ; sinon le guide a été lancé depuis le détail, qui retrouve sa
/// propre origine [via] et le [group] choisi dans le catalogue. Jamais une
/// adresse libre : seules des valeurs de [SheetOrigin] sont écrites.
String guideBackTarget({
  required SheetId sheet,
  Audience? audience,
  String? session,
  SheetOrigin? from,
  SheetOrigin? via,
  GroupId? group,
}) {
  final direct = from == SheetOrigin.catalogue ? null : from;
  return switch (direct ?? (session != null ? SheetOrigin.planner : null)) {
    SheetOrigin.planner => AppRoutes.planner,
    SheetOrigin.today => AppRoutes.home,
    SheetOrigin.suggestion => AppRoutes.session,
    SheetOrigin.catalogue || null => AppRoutes.sheet(
      sheet,
      audience: audience,
      origin: via ?? SheetOrigin.catalogue,
      group: group,
    ),
  };
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

/// Origine directe d'un guide (`?from=`) : absente si la valeur est inconnue
/// ou si c'est le catalogue (qui n'est jamais une origine de lancement).
SheetOrigin? _guideFrom(String? raw) {
  final origin = SheetOrigin.tryParse(raw);
  return origin == SheetOrigin.catalogue ? null : origin;
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
  group: _groupParam(query['group']),
);

GroupId? _groupParam(String? raw) {
  final value = _nonBlank(raw);
  return value == null ? null : GroupId(value);
}

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
      builder: (context, state, child) => BlocProvider(
        create: (_) => getIt<AppUpdateCubit>(),
        child: AppShell(location: state.uri.path, child: child),
      ),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) {
                  final cubit = getIt<BackupReminderCubit>();
                  unawaited(cubit.check());
                  return cubit;
                },
              ),
              BlocProvider(
                create: (_) => getIt<RunningSessionsCubit>()..refresh(),
              ),
              BlocProvider(
                create: (_) {
                  final cubit = getIt<UpcomingSessionsCubit>();
                  unawaited(cubit.load());
                  return cubit;
                },
              ),
              BlocProvider(
                create: (_) {
                  final cubit = getIt<WatchedStudentsCubit>();
                  unawaited(cubit.load());
                  return cubit;
                },
              ),
              BlocProvider(
                create: (_) {
                  final cubit = getIt<GroupAlertsCubit>();
                  unawaited(cubit.load());
                  return cubit;
                },
              ),
              BlocProvider(
                create: (_) {
                  final cubit = getIt<WeekSummaryCubit>();
                  unawaited(cubit.load());
                  return cubit;
                },
              ),
              BlocProvider(
                create: (_) {
                  final cubit = getIt<ClosableSeasonCubit>();
                  unawaited(cubit.load());
                  return cubit;
                },
              ),
            ],
            child: HomePage(
              today: getIt<Clock>().today,
              onOpenPlanner: () => context.go(AppRoutes.planner),
              onOpenSuggestion: () => context.go(AppRoutes.session),
              onAddStudents: () => context.go(AppRoutes.newStudent),
              onOpenStudents: () => context.go(AppRoutes.students),
              onOpenStudent: (id) => context.go(AppRoutes.student(id)),
              onOpenGroup: (id) => context.go(AppRoutes.studentGroup(id)),
              onResume: (key, step) => context.go(
                AppRoutes.guide(
                  key.sheetId,
                  audience: key.audience,
                  session: key.sessionId,
                  step: step,
                  group: key.group,
                  from: SheetOrigin.today,
                  mode: getIt<RunSheetSessions>().of(key).routeMode,
                ),
              ),
              onPrepare: (sheet, audience) => context.go(
                AppRoutes.sheet(
                  sheet,
                  audience: audience,
                  origin: SheetOrigin.today,
                ),
              ),
              onLaunch: (sheet, audience, sessionId) => context.go(
                AppRoutes.guide(
                  sheet,
                  audience: audience,
                  session: sessionId,
                  from: SheetOrigin.today,
                ),
              ),
              onOpenPlanned: () => context.go(AppRoutes.planner),
              onRecord: (group, date, sheet) => context.go(
                AppRoutes.recordFromPlan(
                  group: group,
                  date: date,
                  sheet: sheet,
                ),
              ),
              seasonCard: ClosableSeasonSection(
                onClose: (id) => context.go(AppRoutes.closeSeason(id)),
              ),
              banner: BlocBuilder<BackupReminderCubit, BackupReminder>(
                builder: (context, reminder) => BackupReminderBanner(
                  reminder: reminder,
                  onBackup: () => context.go(AppRoutes.backup),
                ),
              ),
            ),
          ),
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
                    groupId: _groupParam(query['group']),
                    audience:
                        _audienceParam(query['audience']) ?? Audience.children,
                  ),
                ),
              child: SessionPlannerPage(
                onOpenSheet: (id, audience) => context.go(
                  AppRoutes.sheet(
                    id,
                    audience: audience,
                    origin: SheetOrigin.planner,
                  ),
                ),
                onChooseSheet: () => context.go(AppRoutes.catalogue),
                onLaunchSheet: (id, audience, sessionId) => context.go(
                  AppRoutes.guide(
                    id,
                    audience: audience,
                    session: sessionId,
                    from: SheetOrigin.planner,
                  ),
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
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    getIt<StudentsBloc>()..add(const StudentsEvent.started()),
              ),
              BlocProvider(create: (_) => getIt<ManageGroupsCubit>()),
            ],
            child: StudentsPage(
              onOpenStudent: (id) => context.go(AppRoutes.student(id)),
              onOpenGroup: (id) => context.go(AppRoutes.studentGroup(id)),
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
          path: '${AppRoutes.students}/${AppRoutes.groupsSegment}/:groupId',
          builder: (context, state) {
            final id = GroupId(state.pathParameters['groupId']!);
            return BlocProvider(
              create: (_) {
                final cubit = getIt<GroupOverviewCubit>();
                unawaited(cubit.load(id));
                return cubit;
              },
              child: GroupOverviewPage(
                onBack: () => context.go(AppRoutes.students),
                onOpenStudent: (student) =>
                    context.go(AppRoutes.student(student)),
              ),
            );
          },
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
                BlocProvider(create: (_) => getIt<AcknowledgementBloc>()),
                BlocProvider(create: (_) => getIt<MoveStudentCubit>()),
              ],
              child: StudentSheetPage(
                today: getIt<Clock>().today,
                onBack: () => context.go(AppRoutes.students),
                onEdit: () => context.go(AppRoutes.editStudent(id)),
                onOpenAssessment: () => context.go(AppRoutes.assessment(id)),
                onErased: () => context.go(AppRoutes.students),
                onShow: () => context.go(AppRoutes.showcase(id)),
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
            final exerciseBlock = query['exercise_block'];
            final from = _guideReturn(query['from']);
            final sheet = SheetId.tryParse(query['sheet']);
            final today = getIt<Clock>().today();
            return buildRecordSetup(
              today: today,
              main: query['main'],
              recall: query['recall'],
              sheet: sheet,
              group: group == null ? null : GroupId(group),
              absent: absent,
              date: _dateParam(query['date']),
              onOpened: (opened) {
                // La séance guidée retient le choix : l'exercice suivant
                // ne redemande ni groupe, ni présents, ni date.
                final key = from == null ? null : _guideKey(from);
                if (key != null) {
                  getIt<RunSheetSessions>()
                      .of(key)
                      .recordChosen(
                        recordId: opened.id,
                        group: opened.group,
                        date: opened.date,
                        absent: opened.absent,
                      );
                }
                context.go(
                  AppRoutes.recordSession(
                    opened.id,
                    exercise: exercise,
                    exerciseBlock: exerciseBlock,
                    from: from,
                  ),
                );
              },
              onAddStudents: () => context.go(AppRoutes.newStudent),
              onBackToGuide: from == null ? null : () => context.go(from),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.record}/:sessionId/${AppRoutes.reviewSegment}',
          builder: (context, state) {
            final id = SessionId(state.pathParameters['sessionId']!);
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      getIt<SessionReviewBloc>()
                        ..add(SessionReviewEvent.started(id)),
                ),
                BlocProvider(create: (_) => getIt<NextSheetCubit>()),
                BlocProvider(create: (_) => getIt<PlanNextSessionCubit>()),
              ],
              child: SessionReviewPage(
                today: getIt<Clock>().today,
                onBackToday: () => context.go(AppRoutes.home),
                onOpenRecord: (id) => context.go(AppRoutes.recordSession(id)),
                onEnterResults: (id) => context.go(AppRoutes.recordSession(id)),
                onOpenStudent: (id) => context.go(AppRoutes.student(id)),
                onOpenPlanner: (sheet, audience) =>
                    context.go(AppRoutes.plan(sheet, audience: audience)),
                onOpenPlanned: () => context.go(AppRoutes.planner),
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.record}/:sessionId',
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final from = _guideReturn(query['from']);
            return buildRecordSession(
              id: SessionId(state.pathParameters['sessionId']!),
              exercise: int.tryParse(query['exercise'] ?? ''),
              exerciseBlock: query['exercise_block'],
              onBack: () => context.go(from ?? AppRoutes.record),
              fromGuide: from != null,
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
              onRecord: (group, main, recall, sheet) => context.go(
                AppRoutes.recordFromSuggestion(
                  group: group,
                  main: main,
                  recall: recall,
                  sheet: sheet,
                ),
              ),
              onOpenSheet: (id, audience) => context.go(
                AppRoutes.sheet(
                  id,
                  audience: audience,
                  origin: SheetOrigin.suggestion,
                ),
              ),
              // Le groupe et les élèves sont déjà choisis : on mène.
              onLaunch: (id, audience, group) => context.go(
                AppRoutes.guide(
                  id,
                  audience: audience,
                  group: group,
                  from: SheetOrigin.suggestion,
                  mode: RunMode.lead,
                ),
              ),
              onPlan: (id, audience) =>
                  context.go(AppRoutes.plan(id, audience: audience)),
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
          builder: (context, state) {
            final initialGroup = _groupParam(
              state.uri.queryParameters['group'],
            );
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      getIt<SheetCatalogueBloc>()
                        ..add(const SheetCatalogueEvent.started()),
                ),
                BlocProvider(
                  create: (_) {
                    final cubit = getIt<GroupJourneyCubit>();
                    unawaited(cubit.load(initial: initialGroup));
                    return cubit;
                  },
                ),
              ],
              child: SheetCataloguePage(
                onOpenSheet: (id, group) =>
                    context.go(AppRoutes.sheet(id, group: group)),
              ),
            );
          },
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
            final origin = SheetOrigin.parse(state.uri.queryParameters['from']);
            final group = _groupParam(state.uri.queryParameters['group']);
            return BlocProvider(
              create: (_) => getIt<SheetDetailBloc>()
                ..add(
                  SheetDetailEvent.started(sheetId: id, audience: audience),
                ),
              child: SheetDetailPage(
                backLabel: switch (origin) {
                  SheetOrigin.planner => AppLocalizations.of(
                    context,
                  ).plannerTitle,
                  SheetOrigin.today => AppLocalizations.of(context).navHome,
                  SheetOrigin.suggestion => AppLocalizations.of(
                    context,
                  ).suggestTitle,
                  SheetOrigin.catalogue => AppLocalizations.of(
                    context,
                  ).catalogueTitle,
                },
                onBack: () => context.go(switch (origin) {
                  SheetOrigin.planner => AppRoutes.planner,
                  SheetOrigin.today => AppRoutes.home,
                  SheetOrigin.suggestion => AppRoutes.session,
                  SheetOrigin.catalogue => AppRoutes.catalogueFor(group),
                }),
                onHome: () => context.go(AppRoutes.home),
                onPlan: (audience) => context.go(
                  AppRoutes.plan(id, audience: audience, group: group),
                ),
                onLaunch: (audience) => context.go(
                  AppRoutes.guide(
                    id,
                    audience: audience,
                    group: group,
                    via: origin,
                  ),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.backup,
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<BackupBloc>()..add(const BackupEvent.started()),
            child: BackupPage(
              today: getIt<Clock>().today(),
              onBack: () => context.go(AppRoutes.more),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.more,
          builder: (context, state) => MorePage(
            onOpenBackup: () => context.go(AppRoutes.backup),
            onOpenSettings: () => context.go(AppRoutes.settings),
            onOpenSeasons: () => context.go(AppRoutes.seasons),
          ),
        ),
        GoRoute(
          path: AppRoutes.seasons,
          builder: (context, state) => BlocProvider(
            create: (_) {
              final cubit = getIt<SeasonArchivesCubit>();
              unawaited(cubit.load());
              return cubit;
            },
            child: SeasonArchivePage(onBack: () => context.go(AppRoutes.more)),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => BlocProvider(
            create: (_) =>
                getIt<SettingsBloc>()..add(const SettingsEvent.started()),
            child: SettingsPage(onBack: () => context.go(AppRoutes.more)),
          ),
        ),
      ],
    ),
    // Hors du cadre de navigation : l'assistant de clôture ne se quitte pas à
    // mi-chemin par un geste de navigation (ADR 0019).
    GoRoute(
      path: '${AppRoutes.seasons}/:seasonId/${AppRoutes.closeSegment}',
      builder: (context, state) {
        final id = SeasonId(state.pathParameters['seasonId']!);
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  getIt<SeasonClosureBloc>()
                    ..add(SeasonClosureEvent.started(seasonId: id)),
            ),
            BlocProvider(
              create: (_) =>
                  getIt<BackupBloc>()..add(const BackupEvent.started()),
            ),
          ],
          child: SeasonClosurePage(
            today: getIt<Clock>().today(),
            onCancel: () => context.go(AppRoutes.home),
            onSeasons: () => context.go(AppRoutes.seasons),
            onHome: () => context.go(AppRoutes.home),
          ),
        );
      },
    ),
    // Hors du cadre de navigation : l'écran montré à l'élève n'offre aucun
    // chemin vers les autres élèves (décision Q6).
    GoRoute(
      path: '${AppRoutes.students}/:studentId/${AppRoutes.showcaseSegment}',
      builder: (context, state) {
        final id = _studentId(state);
        return BlocProvider(
          create: (_) {
            final cubit = getIt<ShowcaseCubit>();
            unawaited(cubit.load(id));
            return cubit;
          },
          child: StudentShowcasePage(
            studentId: id,
            onDone: () => context.go(AppRoutes.student(id)),
          ),
        );
      },
    ),
    // Hors du cadre de navigation, comme la présentation : en séance, ni rail
    // ni barre. Le cubit vit dans `RunSheetSessions`, pas dans la route :
    // sortir par la flèche ne termine rien (reprise depuis Aujourd'hui).
    GoRoute(
      path: '${AppRoutes.catalogue}/:sheetId/${AppRoutes.guideSegment}',
      builder: (context, state) {
        final id = SheetId.tryParse(state.pathParameters['sheetId']);
        if (id == null) {
          return NotFoundPage(onHome: () => context.go(AppRoutes.home));
        }
        final query = state.uri.queryParameters;
        final key = _runKey(id, query);
        final from = _guideFrom(query['from']);
        final via = SheetOrigin.tryParse(query['via']);
        final sessions = getIt<RunSheetSessions>();
        final cubit = sessions.of(key);
        unawaited(
          cubit.syncFromRoute(
            step: int.tryParse(query['step'] ?? ''),
            mode: RunMode.tryParse(query['mode']),
          ),
        );
        // Les paramètres du guide sont reportés tels quels à chaque adresse
        // reconstruite (étape suivante, présentation) ; le mode, lui, vient du
        // cubit, qui fait foi.
        String guide(int? step) => AppRoutes.guide(
          id,
          audience: key.audience,
          session: key.sessionId,
          step: step,
          group: key.group,
          from: from,
          via: via,
          mode: cubit.routeMode,
        );
        // Retour et fin sans bilan : l'origine du lancement (U-9).
        String back() => guideBackTarget(
          sheet: id,
          audience: key.audience,
          session: key.sessionId,
          from: from,
          via: via,
          group: key.group,
        );
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider(create: (_) => getIt<FullscreenCubit>()),
          ],
          child: SheetGuidePage(
            onBack: () => context.go(back()),
            onHome: () => context.go(AppRoutes.home),
            onShow: (step) => context.push(
              AppRoutes.presentation(
                id,
                audience: key.audience,
                session: key.sessionId,
                step: step,
                group: key.group,
                from: from,
                via: via,
                mode: cubit.routeMode,
              ),
            ),
            // U5 : feuille basse sur l'exercice courant ; le guide reste
            // monté à la même étape (la route plein écran reste valide).
            onRecord: (exercise, main, recall) {
              final defaults = cubit.state.recordDefaults;
              unawaited(
                showRecordSheet(
                  context,
                  key: key,
                  sheet: id,
                  exercise: exercise.number,
                  exerciseBlock: exercise.blockId,
                  main: main,
                  recall: recall,
                  group: defaults.group ?? key.group,
                  absent: defaults.absent,
                  date: defaults.date,
                  onAddStudents: () => context.go(AppRoutes.newStudent),
                ),
              );
            },
            // Une saisie ouverte depuis ce guide : le bilan (U7) ; sinon,
            // retour d'où le guide a été lancé.
            onFinish: (recordId) {
              context.go(
                recordId == null ? back() : AppRoutes.review(recordId),
              );
              unawaited(sessions.release(key));
            },
            onStepChanged: (step) => context.go(guide(step)),
          ),
        );
      },
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
        final group = _groupParam(query['group']);
        final from = _guideFrom(query['from']);
        final via = SheetOrigin.tryParse(query['via']);
        final mode = RunMode.tryParse(query['mode']);
        return MultiBlocProvider(
          providers: [
            BlocProvider(
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
            ),
            BlocProvider(create: (_) => getIt<FullscreenCubit>()),
          ],
          child: SheetPresentationPage(
            onClose: (step) => context.go(
              AppRoutes.guide(
                id,
                audience: audience,
                session: session,
                step: step,
                group: group,
                from: from,
                via: via,
                mode: mode,
              ),
            ),
            onHome: () => context.go(AppRoutes.home),
          ),
        );
      },
    ),
  ],
);
