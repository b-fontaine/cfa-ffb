part of 'audience_change_bloc.dart';

enum AudienceChangeStatus { idle, saving, changed, failure }

@freezed
abstract class AudienceChangeState with _$AudienceChangeState {
  const factory AudienceChangeState({
    @Default(AudienceChangeStatus.idle) AudienceChangeStatus status,
    AudienceChangeOutcome? outcome,
    Failure? failure,
  }) = _AudienceChangeState;
}
