import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/record_screens.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/material.dart';

/// Ouvre la saisie des résultats en feuille basse depuis la séance guidée
/// (U5) : le guide reste monté à la même étape, fermer la feuille y ramène
/// sans rien perdre. La route plein écran (liens profonds, ADR 0007) reste
/// valide pour les autres entrées.
Future<void> showRecordSheet(
  BuildContext context, {
  required RunKey key,
  required SheetId sheet,
  required int exercise,
  required String exerciseBlock,
  required String main,
  String? recall,
  GroupId? group,
  Set<StudentId> absent = const {},
  DateTime? date,
  VoidCallback? onAddStudents,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (sheetContext) => _RecordSheet(
      key: const ValueKey('record-sheet'),
      runKey: key,
      sheet: sheet,
      exercise: exercise,
      exerciseBlock: exerciseBlock,
      main: main,
      recall: recall,
      group: group,
      absent: absent,
      date: date,
      onClose: () => Navigator.of(sheetContext).pop(),
      onAddStudents: onAddStudents,
    ),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({
    required this.runKey,
    required this.sheet,
    required this.exercise,
    required this.exerciseBlock,
    required this.main,
    required this.recall,
    required this.group,
    required this.absent,
    required this.date,
    required this.onClose,
    required this.onAddStudents,
    super.key,
  });

  final RunKey runKey;
  final SheetId sheet;
  final int exercise;
  final String exerciseBlock;
  final String main;
  final String? recall;
  final GroupId? group;
  final Set<StudentId> absent;
  final DateTime? date;
  final VoidCallback onClose;
  final VoidCallback? onAddStudents;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  SessionId? _opened;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final opened = _opened;
    return SizedBox(
      height: height,
      child: opened == null ? _setup(context) : _session(opened),
    );
  }

  Widget _setup(BuildContext context) {
    return buildRecordSetup(
      today: getIt<Clock>().today(),
      main: widget.main,
      recall: widget.recall,
      sheet: widget.sheet,
      group: widget.group,
      absent: widget.absent,
      date: widget.date,
      onOpened: (opened) {
        // Le guide retient le choix : l'exercice suivant ne redemande rien.
        getIt<RunSheetSessions>()
            .of(widget.runKey)
            .recordChosen(
              recordId: opened.id,
              group: opened.group,
              date: opened.date,
              absent: opened.absent,
            );
        setState(() => _opened = opened.id);
      },
      onAddStudents: () {
        widget.onClose();
        widget.onAddStudents?.call();
      },
      onBackToGuide: widget.onClose,
    );
  }

  Widget _session(SessionId id) => buildRecordSession(
    id: id,
    exercise: widget.exercise,
    exerciseBlock: widget.exerciseBlock,
    onBack: widget.onClose,
    fromGuide: true,
  );
}
