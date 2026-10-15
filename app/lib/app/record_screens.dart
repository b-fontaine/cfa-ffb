import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/students_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/open_session_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/session_date_cubit.dart';
import 'package:billard_cfa/pages/record_session/presentation/record_session_page.dart';
import 'package:billard_cfa/pages/record_setup/presentation/record_setup_page.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_selection_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Câblage de l'ouverture d'une saisie (`RecordSetupPage`) : blocs, groupe et
/// présents présélectionnés, date. Unique pour la route `/record/new` et la
/// feuille basse du guide (U5) ; seuls les callbacks de sortie diffèrent.
Widget buildRecordSetup({
  required DateTime today,
  required void Function(OpenedRecord opened) onOpened,
  required VoidCallback onAddStudents,
  String? main,
  String? recall,
  SheetId? sheet,
  GroupId? group,
  Set<StudentId> absent = const {},
  DateTime? date,
  VoidCallback? onBackToGuide,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            getIt<StudentsBloc>()..add(const StudentsEvent.started()),
      ),
      BlocProvider(create: (_) => getIt<OpenSessionBloc>()),
      BlocProvider(
        create: (_) =>
            getIt<RosterSelectionCubit>(param1: group, param2: absent),
      ),
      BlocProvider(
        create: (_) => getIt<SessionDateCubit>(param1: date ?? today),
      ),
    ],
    child: RecordSetupPage(
      today: today,
      mainBlockId: main,
      recallBlockId: recall,
      sheetId: sheet,
      onOpened: onOpened,
      onAddStudents: onAddStudents,
      onBackToGuide: onBackToGuide,
    ),
  );
}

/// Câblage de la saisie d'une séance ouverte (`RecordSessionPage`) : unique
/// pour la route `/record/:sessionId` et la feuille basse du guide.
Widget buildRecordSession({
  required SessionId id,
  required VoidCallback onBack,
  required bool fromGuide,
  int? exercise,
  String? exerciseBlock,
}) {
  return BlocProvider(
    create: (_) => getIt<RecordResultsBloc>()
      ..add(
        RecordResultsEvent.started(
          sessionId: id,
          initialExercise: exercise,
          initialBlock: exerciseBlock,
        ),
      ),
    child: RecordSessionPage(onBack: onBack, fromGuide: fromGuide),
  );
}
