part of 'placement_bloc.dart';

@freezed
sealed class PlacementEvent with _$PlacementEvent {
  const factory PlacementEvent.markRequested({
    required StudentId studentId,
    required String blockId,
    required DateTime date,
  }) = PlacementMarkRequested;

  const factory PlacementEvent.revokeRequested({
    required StudentId studentId,
    required String blockId,
  }) = PlacementRevokeRequested;
}
