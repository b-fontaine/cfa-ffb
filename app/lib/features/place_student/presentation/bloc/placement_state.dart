part of 'placement_bloc.dart';

enum PlacementStatus { idle, working, done, refused }

enum PlacementAction { mark, revoke }

/// Dernière demande de positionnement : son [action], le [blockId] visé et
/// son issue ([failure] quand elle est refusée).
@freezed
abstract class PlacementState with _$PlacementState {
  const factory PlacementState({
    @Default(PlacementStatus.idle) PlacementStatus status,
    PlacementAction? action,
    String? blockId,
    Failure? failure,
  }) = _PlacementState;
}
