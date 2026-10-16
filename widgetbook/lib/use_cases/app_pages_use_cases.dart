import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/acknowledge_alert/presentation/bloc/acknowledgement_bloc.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/features/manage_settings/presentation/bloc/settings_bloc.dart';
import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/open_session_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/session_date_cubit.dart';
import 'package:billard_cfa/features/student_showcase/presentation/bloc/showcase_cubit.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/exercise_sheet_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/features/track_group/presentation/bloc/group_overview_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/pages/assessment/presentation/assessment_page.dart';
import 'package:billard_cfa/pages/backup/presentation/backup_page.dart';
import 'package:billard_cfa/pages/exercise_sheet/presentation/exercise_sheet_page.dart';
import 'package:billard_cfa/pages/group_overview/presentation/group_overview_page.dart';
import 'package:billard_cfa/pages/more/presentation/more_page.dart';
import 'package:billard_cfa/pages/record_session/presentation/record_session_page.dart';
import 'package:billard_cfa/pages/record_setup/presentation/record_setup_page.dart';
import 'package:billard_cfa/pages/settings/presentation/settings_page.dart';
import 'package:billard_cfa/pages/student_form/presentation/student_form_page.dart';
import 'package:billard_cfa/pages/student_sheet/presentation/student_sheet_page.dart';
import 'package:billard_cfa/pages/student_showcase/presentation/student_showcase_page.dart';
import 'package:billard_cfa/pages/students/presentation/students_page.dart';
import 'package:billard_cfa/pages/suggested_session/presentation/suggested_session_page.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_picker.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_selection_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _path = '[Pages]';

@widgetbook.UseCase(name: 'Élèves', type: StudentsPage, path: _path)
Widget buildStudentsPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<StudentsBloc>()..add(const StudentsEvent.started()),
    child: StudentsPage(
      onOpenStudent: (_) {},
      onOpenGroup: (_) {},
      onAddStudent: () {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Ajout d’un élève',
  type: StudentFormPage,
  path: _path,
)
Widget buildStudentFormPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<StudentFormBloc>()..add(const StudentFormEvent.started()),
    child: StudentFormPage(onSaved: (_) {}, onBack: () {}),
  ),
);

@widgetbook.UseCase(name: 'Fiche élève', type: StudentSheetPage, path: _path)
Widget buildStudentSheetPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            getIt<StudentSheetBloc>()
              ..add(StudentSheetEvent.started(studentId: world.children.id)),
      ),
      BlocProvider(
        create: (_) =>
            getIt<StudentRecallBloc>()
              ..add(StudentRecallEvent.started(studentId: world.children.id)),
      ),
      BlocProvider(create: (_) => getIt<StudentErasureBloc>()),
      BlocProvider(create: (_) => getIt<PlacementBloc>()),
      BlocProvider(create: (_) => getIt<AcknowledgementBloc>()),
    ],
    child: StudentSheetPage(
      today: () => world.today,
      onBack: () {},
      onEdit: () {},
      onOpenAssessment: () {},
      onErased: () {},
      onShow: () {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Vue à montrer à l’élève',
  type: StudentShowcasePage,
  path: _path,
)
Widget buildStudentShowcasePageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) {
      final cubit = getIt<ShowcaseCubit>();
      unawaited(cubit.load(world.children.id));
      return cubit;
    },
    child: StudentShowcasePage(studentId: world.children.id, onDone: () {}),
  ),
);

@widgetbook.UseCase(name: 'Vue de groupe', type: GroupOverviewPage, path: _path)
Widget buildGroupOverviewPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) {
      final cubit = getIt<GroupOverviewCubit>();
      unawaited(cubit.load(world.childrenGroup));
      return cubit;
    },
    child: GroupOverviewPage(onBack: () {}, onOpenStudent: (_) {}),
  ),
);

@widgetbook.UseCase(
  name: 'Bilan de maturité',
  type: AssessmentPage,
  path: _path,
)
Widget buildAssessmentPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            getIt<StudentSheetBloc>()
              ..add(StudentSheetEvent.started(studentId: world.children.id)),
      ),
      BlocProvider(create: (_) => getIt<AssessmentBloc>()),
      BlocProvider(create: (_) => getIt<AudienceChangeBloc>()),
    ],
    child: AssessmentPage(
      onBack: () {},
      today: world.today,
      readinessMinScore: 3,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Préparer la saisie',
  type: RecordSetupPage,
  path: _path,
)
Widget buildRecordSetupPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            getIt<StudentsBloc>()..add(const StudentsEvent.started()),
      ),
      BlocProvider(create: (_) => getIt<OpenSessionBloc>()),
      BlocProvider(create: (_) => getIt<RosterSelectionCubit>()),
      BlocProvider(create: (_) => getIt<SessionDateCubit>(param1: world.today)),
    ],
    child: RecordSetupPage(
      today: world.today,
      onOpened: (_) {},
      onAddStudents: () {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Saisie d’une séance',
  type: RecordSessionPage,
  path: _path,
)
Widget buildRecordSessionPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<RecordResultsBloc>()
          ..add(RecordResultsEvent.started(sessionId: world.sessionId)),
    child: RecordSessionPage(onBack: () {}),
  ),
);

@widgetbook.UseCase(
  name: 'Séance suggérée',
  type: SuggestedSessionPage,
  path: _path,
)
Widget buildSuggestedSessionPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            getIt<StudentsBloc>()..add(const StudentsEvent.started()),
      ),
      BlocProvider(create: (_) => getIt<SuggestedSessionBloc>()),
      BlocProvider(create: (_) => getIt<RosterSelectionCubit>()),
    ],
    child: SuggestedSessionPage(
      onOpenSource: (_) {},
      onRecord: (_, _, _, _) {},
      onOpenSheet: (_, _) {},
      onLaunch: (_, _, _) {},
      onPlan: (_, _) {},
      onAddStudents: () {},
    ),
  ),
);

@widgetbook.UseCase(name: 'Fiche source', type: ExerciseSheetPage, path: _path)
Widget buildExerciseSheetPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<ExerciseSheetBloc>()
          ..add(ExerciseSheetEvent.started(exercise: PreviewWorld.validated)),
    child: ExerciseSheetPage(onBack: () {}),
  ),
);

@widgetbook.UseCase(name: 'Plus', type: MorePage, path: _path)
Widget buildMorePageUseCase(BuildContext context) =>
    MorePage(onOpenBackup: () {}, onOpenSettings: () {}, onOpenSeasons: () {});

@widgetbook.UseCase(name: 'Réglages', type: SettingsPage, path: _path)
Widget buildSettingsPageUseCase(BuildContext context) => BlocProvider(
  create: (_) => getIt<SettingsBloc>()..add(const SettingsEvent.started()),
  child: SettingsPage(onBack: () {}),
);

@widgetbook.UseCase(name: 'Sauvegarde', type: BackupPage, path: _path)
Widget buildBackupPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<BackupBloc>()..add(const BackupEvent.started()),
    child: BackupPage(today: world.today, onBack: () {}),
  ),
);

@widgetbook.UseCase(
  name: 'Sélection des présents',
  type: RosterPicker,
  path: '[Widgets]',
)
Widget buildRosterPickerUseCase(BuildContext context) => LoadedScope(
  load: (world) => getIt<GetClubOverview>()(today: world.today),
  builder: (context, world, club) => _RosterDemo(club.groups),
);

class _RosterDemo extends StatefulWidget {
  const _RosterDemo(this.groups);

  final List<GroupOverview> groups;

  @override
  State<_RosterDemo> createState() => _RosterDemoState();
}

class _RosterDemoState extends State<_RosterDemo> {
  late GroupId _group = widget.groups.first.group.id;
  late Set<StudentId> _present = {
    for (final member in widget.groups.first.members) member.student.id,
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: RosterPicker(
      groups: widget.groups,
      selectedGroupId: _group,
      present: _present,
      onGroupSelected: (id) => setState(() {
        _group = id;
        _present = {};
      }),
      onPresenceChanged: (student, {required isPresent}) => setState(() {
        _present = {
          for (final id in _present)
            if (id != student) id,
          if (isPresent) student,
        };
      }),
    ),
  );
}
