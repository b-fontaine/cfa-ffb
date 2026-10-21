import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/foundation.dart';

/// Les commandes de l'écran d'import : l'interface les appelle, sans connaître
/// le cubit (les use cases du Widgetbook leur donnent [none]).
@immutable
final class ClubImportActions {
  const ClubImportActions({
    required this.onPick,
    required this.onChooseGroup,
    required this.onConfirmMerge,
    required this.onChooseSession,
    required this.onChooseStudent,
    required this.onConfirmRestore,
    required this.onConfirmUnverified,
    required this.onNext,
    required this.onBack,
    required this.onRestart,
    required this.onStart,
    required this.onCancel,
    required this.onResume,
    required this.onFinish,
  });

  /// Les commandes du cubit ; [onFinish] ramène à « Plus ».
  factory ClubImportActions.of(
    ClubImportCubit cubit, {
    required VoidCallback onFinish,
  }) => ClubImportActions(
    onPick: cubit.pickFile,
    onChooseGroup: cubit.chooseGroup,
    onConfirmMerge: (target, {required confirmed}) =>
        cubit.confirmMerge(target, confirmed: confirmed),
    onChooseSession: cubit.chooseSession,
    onChooseStudent: cubit.chooseStudent,
    onConfirmRestore: ({required confirmed}) =>
        cubit.confirmRestore(confirmed: confirmed),
    onConfirmUnverified: ({required confirmed}) =>
        cubit.confirmUnverified(confirmed: confirmed),
    onNext: cubit.next,
    onBack: cubit.back,
    onRestart: cubit.restart,
    onStart: cubit.start,
    onCancel: cubit.cancel,
    onResume: cubit.resume,
    onFinish: onFinish,
  );

  /// Aucune commande (aperçus).
  static const none = ClubImportActions(
    onPick: _noop,
    onChooseGroup: _noChoice,
    onConfirmMerge: _noMerge,
    onChooseSession: _noOwner,
    onChooseStudent: _noStudent,
    onConfirmRestore: _noConfirm,
    onConfirmUnverified: _noConfirm,
    onNext: _noSync,
    onBack: _noSync,
    onRestart: _noSync,
    onStart: _noop,
    onCancel: _noSync,
    onResume: _noop,
    onFinish: _noSync,
  );

  final Future<void> Function() onPick;
  final Future<void> Function(GroupId fileGroup, GroupChoice? choice)
  onChooseGroup;
  final Future<void> Function(GroupId target, {required bool confirmed})
  onConfirmMerge;
  final Future<void> Function(String id, OwnerChoice? choice) onChooseSession;
  final Future<void> Function(StudentId id, OwnerChoice? choice)
  onChooseStudent;
  final Future<void> Function({required bool confirmed}) onConfirmRestore;
  final Future<void> Function({required bool confirmed}) onConfirmUnverified;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final Future<void> Function() onStart;
  final VoidCallback onCancel;
  final Future<void> Function() onResume;
  final VoidCallback onFinish;
}

Future<void> _noop() async {}
void _noSync() {}
Future<void> _noChoice(GroupId group, GroupChoice? choice) async {}
Future<void> _noMerge(GroupId target, {required bool confirmed}) async {}
Future<void> _noOwner(String id, OwnerChoice? choice) async {}
Future<void> _noStudent(StudentId id, OwnerChoice? choice) async {}
Future<void> _noConfirm({required bool confirmed}) async {}
