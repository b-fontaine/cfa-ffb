import 'package:billard_cfa/features/track_group/domain/list_group_alerts.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'group_alerts_cubit.freezed.dart';

enum GroupAlertsStatus { loading, ready, failure }

@freezed
abstract class GroupAlertsState with _$GroupAlertsState {
  const factory GroupAlertsState({
    @Default(GroupAlertsStatus.loading) GroupAlertsStatus status,
    @Default(GroupAlertList()) GroupAlertList alerts,
    Failure? failure,
  }) = _GroupAlertsState;
}

/// Section « Alertes de groupe » de l'accueil.
@injectable
class GroupAlertsCubit extends Cubit<GroupAlertsState> {
  GroupAlertsCubit(this._list, this._clock) : super(const GroupAlertsState());

  final ListGroupAlerts _list;
  final Clock _clock;

  /// (Re)charge la section ; sert aussi de « Réessayer ».
  Future<void> load() async {
    if (state.status != GroupAlertsStatus.loading) {
      emit(const GroupAlertsState());
    }
    final result = await _list(today: _clock.today());
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => GroupAlertsState(
        status: GroupAlertsStatus.ready,
        alerts: value,
      ),
      Err(:final failure) => GroupAlertsState(
        status: GroupAlertsStatus.failure,
        failure: failure,
      ),
    });
  }
}
