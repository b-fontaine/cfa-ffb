import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'roster_selection_cubit.freezed.dart';

/// Groupe choisi et élèves cochés, résolus contre les groupes éligibles.
@freezed
abstract class RosterSelection with _$RosterSelection {
  const factory RosterSelection({
    required GroupOverview group,
    required Set<StudentId> present,
  }) = _RosterSelection;
}

/// Choix de l'animateur dans le `RosterPicker` : groupe demandé et élèves
/// décochés. Par défaut, le premier groupe et tous ses membres.
@freezed
abstract class RosterSelectionState with _$RosterSelectionState {
  const factory RosterSelectionState({
    GroupId? groupId,
    @Default(<StudentId>{}) Set<StudentId> absent,
  }) = _RosterSelectionState;

  const RosterSelectionState._();

  /// Sélection effective parmi [groups] (déjà éligibles), `null` sans groupe.
  /// Un groupe demandé inconnu retombe sur le premier.
  RosterSelection? resolve(List<GroupOverview> groups) {
    if (groups.isEmpty) return null;
    final group = groups.firstWhere(
      (candidate) => candidate.group.id == groupId,
      orElse: () => groups.first,
    );
    return RosterSelection(
      group: group,
      present: {
        for (final member in group.members)
          if (!absent.contains(member.student.id)) member.student.id,
      },
    );
  }
}

/// État de sélection partagé par les écrans qui composent un
/// `RosterPicker` (ouverture d'une séance, séance suggérée).
@injectable
class RosterSelectionCubit extends Cubit<RosterSelectionState> {
  RosterSelectionCubit({@factoryParam GroupId? initialGroupId})
    : super(RosterSelectionState(groupId: initialGroupId));

  /// Change de groupe : les absences du groupe précédent sont oubliées.
  void groupSelected(GroupId groupId) =>
      emit(RosterSelectionState(groupId: groupId));

  void presenceChanged(StudentId student, {required bool isPresent}) {
    final absent = {...state.absent};
    if (isPresent) {
      absent.remove(student);
    } else {
      absent.add(student);
    }
    emit(state.copyWith(absent: absent));
  }
}
