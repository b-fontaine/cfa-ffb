import 'package:billard_cfa/features/track_group/domain/get_group_overview.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'group_overview_cubit.freezed.dart';

enum GroupOverviewStatus { loading, ready, failure }

@freezed
abstract class GroupOverviewState with _$GroupOverviewState {
  const factory GroupOverviewState({
    GroupId? groupId,
    @Default(GroupOverviewStatus.loading) GroupOverviewStatus status,
    GroupGrid? grid,
    Failure? failure,
  }) = _GroupOverviewState;
}

/// La vue de groupe : grille technique × élève, assiduité, alertes.
@injectable
class GroupOverviewCubit extends Cubit<GroupOverviewState> {
  GroupOverviewCubit(this._overview, this._clock)
    : super(const GroupOverviewState());

  final GetGroupOverview _overview;
  final Clock _clock;

  Future<void> load(GroupId groupId) async {
    emit(GroupOverviewState(groupId: groupId));
    final result = await _overview(groupId: groupId, today: _clock.today());
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => GroupOverviewState(
        groupId: groupId,
        status: GroupOverviewStatus.ready,
        grid: value,
      ),
      Err(:final failure) => GroupOverviewState(
        groupId: groupId,
        status: GroupOverviewStatus.failure,
        failure: failure,
      ),
    });
  }

  /// Recharge le groupe ouvert ; sert aussi de « Réessayer ».
  Future<void> reload() async {
    final id = state.groupId;
    if (id != null) await load(id);
  }
}
