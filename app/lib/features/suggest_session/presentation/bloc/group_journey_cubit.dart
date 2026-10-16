import 'package:billard_cfa/features/suggest_session/domain/get_group_journey.dart';
import 'package:billard_cfa/features/suggest_session/domain/group_journey.dart';
import 'package:billard_cfa/features/suggest_session/domain/list_journey_groups.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'group_journey_cubit.freezed.dart';

enum GroupJourneyStatus { none, loading, ready, failure }

@freezed
abstract class GroupJourneyState with _$GroupJourneyState {
  const factory GroupJourneyState({
    @Default(GroupJourneyStatus.none) GroupJourneyStatus status,

    /// Le groupe choisi (état d'écran, jamais stocké).
    GroupId? groupId,
    GroupJourney? journey,
    Failure? failure,

    /// Les groupes proposés au sélecteur.
    @Default(<GroupChoice>[]) List<GroupChoice> choices,
  }) = _GroupJourneyState;

  const GroupJourneyState._();

  /// Les marqueurs des séances [ids] ; vides sans groupe, pendant le chargement
  /// et en cas d'échec (jamais de page d'erreur pour un marqueur).
  Map<SheetId, JourneyMark> marksFor(Iterable<SheetId> ids) =>
      status == GroupJourneyStatus.ready && journey != null
      ? journey!.marksFor(ids)
      : const {};
}

/// Le parcours du groupe choisi dans le catalogue. Le dernier choix gagne : le
/// résultat d'un choix périmé est ignoré.
@injectable
class GroupJourneyCubit extends Cubit<GroupJourneyState> {
  GroupJourneyCubit(this._journey, this._groups)
    : super(const GroupJourneyState());

  final GetGroupJourney _journey;
  final ListJourneyGroups _groups;

  /// Charge les groupes proposés ; [initial] (le groupe de l'adresse) est
  /// choisi s'il en fait partie, ignoré sinon. Un échec est gardé dans l'état
  /// et ne bloque pas le catalogue.
  Future<void> load({GroupId? initial}) async {
    final result = await _groups();
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
      case Ok(:final value):
        emit(state.copyWith(choices: value));
        if (initial != null && value.any((choice) => choice.id == initial)) {
          await select(initial);
        }
    }
  }

  /// Choisit [groupId] ; `null` retire le groupe (aucun marqueur).
  Future<void> select(GroupId? groupId) async {
    if (groupId == null) {
      emit(GroupJourneyState(choices: state.choices));
      return;
    }
    final choices = state.choices;
    emit(
      GroupJourneyState(
        status: GroupJourneyStatus.loading,
        groupId: groupId,
        choices: choices,
      ),
    );
    final result = await _journey(groupId);
    if (isClosed || state.groupId != groupId) return;
    emit(switch (result) {
      Ok(:final value) => GroupJourneyState(
        status: GroupJourneyStatus.ready,
        groupId: groupId,
        journey: value,
        choices: choices,
      ),
      Err(:final failure) => GroupJourneyState(
        status: GroupJourneyStatus.failure,
        groupId: groupId,
        failure: failure,
        choices: choices,
      ),
    });
  }
}
