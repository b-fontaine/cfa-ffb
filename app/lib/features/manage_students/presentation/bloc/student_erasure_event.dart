part of 'student_erasure_bloc.dart';

@freezed
sealed class StudentErasureEvent with _$StudentErasureEvent {
  /// L'écran s'ouvre : ce que l'effacement supprimera, et s'il est déjà
  /// commencé.
  const factory StudentErasureEvent.inspected({required StudentId studentId}) =
      StudentErasureInspected;

  /// L'animateur a confirmé (ou reprend) l'effacement.
  const factory StudentErasureEvent.requested({required StudentId studentId}) =
      StudentErasureRequested;

  /// L'animateur demande l'arrêt : l'effacement s'arrête **entre deux lots**,
  /// ce qui reste se reprend plus tard.
  const factory StudentErasureEvent.stopRequested() =
      StudentErasureStopRequested;
}
