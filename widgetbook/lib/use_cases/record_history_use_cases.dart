import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/recorded_sessions_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/attempt_edit_dialog.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/attempt_history.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/recorded_session_list.dart';
import 'package:billard_cfa/pages/record_history/presentation/record_history_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _path = '[Features]';

Widget _scroll(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: child,
);

/// Deux séances d'exemple, sans passer par les dépôts.
List<RecordedSessionSummary> _summaries(PreviewWorld world) => [
  RecordedSessionSummary(
    session: SessionRecord(
      id: const SessionId('demo-2'),
      groupId: world.childrenGroup,
      seasonId: const SeasonId('demo'),
      date: DateTime(2026, 10, 10),
      audience: Audience.children,
      present: {world.children.id},
      mainBlockId: 'puissance',
    ),
    groupName: 'Enfants',
    mainBlock: world.catalogue.blockById('puissance'),
    attemptCount: 3,
    sheet: SheetOption(
      id: SheetId('puissance-1'),
      technique: 'puissance',
      techniqueRank: 2,
      title: 'La puissance',
      part: 1,
      partCount: 2,
    ),
  ),
  RecordedSessionSummary(
    session: SessionRecord(
      id: const SessionId('demo-1'),
      groupId: world.childrenGroup,
      seasonId: const SeasonId('demo'),
      date: DateTime(2026, 10, 3),
      audience: Audience.children,
      present: const {},
    ),
    groupName: 'Enfants',
    mainBlock: null,
    attemptCount: 0,
  ),
];

@widgetbook.UseCase(
  name: 'Historique vide',
  type: RecordedSessionList,
  path: _path,
)
Widget buildRecordedSessionListEmptyUseCase(BuildContext context) =>
    _scroll(RecordedSessionList(sessions: const [], onOpenSession: (_) {}));

@widgetbook.UseCase(
  name: 'Historique avec séances',
  type: RecordedSessionList,
  path: _path,
)
Widget buildRecordedSessionListUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => _scroll(
    RecordedSessionList(sessions: _summaries(world), onOpenSession: (_) {}),
  ),
);

@widgetbook.UseCase(
  name: 'Passages de la séance',
  type: AttemptHistory,
  path: _path,
)
Widget buildAttemptHistoryUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<RecordResultsBloc>()
          ..add(RecordResultsEvent.started(sessionId: world.sessionId)),
    child: BlocBuilder<RecordResultsBloc, RecordResultsState>(
      builder: (context, state) => state.status == RecordStatus.ready
          ? _scroll(AttemptHistory(state: state))
          : const Center(child: CircularProgressIndicator()),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Correction d’un passage',
  type: AttemptEditDialog,
  path: _path,
)
Widget buildAttemptEditDialogUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => AttemptEditDialog(
    studentName: world.children.firstName,
    exerciseTitle: 'La puissance · exercice 2',
    attempt: ExerciseAttempt(
      id: const AttemptId('demo'),
      studentId: world.children.id,
      sessionId: world.sessionId,
      exercise: PreviewWorld.struggling,
      date: world.today,
      passIndex: 1,
      potted: 5,
      total: 9,
    ),
    rate: SuccessRate(successes: 7, attempts: 9),
    onSave: (_, _) {},
  ),
);

@widgetbook.UseCase(
  name: 'Historique des séances',
  type: RecordHistoryPage,
  path: '[Pages]',
)
Widget buildRecordHistoryPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<RecordedSessionsBloc>()
          ..add(const RecordedSessionsEvent.started()),
    child: RecordHistoryPage(onOpenSession: (_) {}, onNewSession: () {}),
  ),
);
