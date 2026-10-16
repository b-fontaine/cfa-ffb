import 'package:billard_cfa/features/change_audience/domain/audience_change_outcome.dart';
import 'package:billard_cfa/features/change_audience/domain/change_audience.dart';
import 'package:billard_cfa/features/change_audience/domain/list_destination_groups.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'audience_change_bloc.freezed.dart';
part 'audience_change_event.dart';
part 'audience_change_state.dart';

/// Changement de public : toujours une action manuelle de l'animateur.
@injectable
class AudienceChangeBloc
    extends Bloc<AudienceChangeEvent, AudienceChangeState> {
  AudienceChangeBloc(this._change, this._destinations, this._clock)
    : super(const AudienceChangeState()) {
    on<AudienceChangeRequested>(_onRequested);
  }

  final ChangeAudience _change;
  final ListDestinationGroups _destinations;
  final Clock _clock;

  Future<void> _onRequested(
    AudienceChangeRequested event,
    Emitter<AudienceChangeState> emit,
  ) async {
    emit(const AudienceChangeState(status: AudienceChangeStatus.saving));
    final result = await _change(
      studentId: event.studentId,
      audience: event.audience,
      effectiveFrom: _clock.today(),
      groupName: event.groupName,
      destinationGroupId: event.destinationGroupId,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          AudienceChangeState(
            status: AudienceChangeStatus.changed,
            outcome: value,
          ),
        );
      case Err(:final failure):
        // Plusieurs groupes conviennent : on propose le choix (ADR 0019).
        var choices = const <GroupChoice>[];
        if (failure is InvariantViolation &&
            failure.code == InvariantCode.groupChoiceRequired) {
          final listed = await _destinations(
            studentId: event.studentId,
            audience: event.audience,
            today: _clock.today(),
          );
          if (listed case Ok(:final value)) choices = value;
        }
        emit(
          AudienceChangeState(
            status: AudienceChangeStatus.failure,
            failure: failure,
            choices: choices,
          ),
        );
    }
  }
}
