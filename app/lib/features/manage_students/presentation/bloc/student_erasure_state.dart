part of 'student_erasure_bloc.dart';

enum StudentErasureStatus {
  /// Avant la lecture de ce que l'effacement supprimera.
  idle,

  /// Prêt : l'effacement n'est pas commencé, ou est à reprendre (`inProgress`).
  ready,

  /// En cours : `done` lots sur `total`.
  working,

  /// Terminé : la fiche n'existe plus.
  erased,

  /// Arrêté par l'animateur entre deux lots : reprendre pour terminer.
  stopped,

  /// Interrompu par le réseau : rien n'est perdu, reprendre plus tard.
  interrupted,

  /// Plafond d'écritures du jour atteint : reprendre un autre jour.
  paused,

  /// Refusé ou échoué : rien n'a été effacé par le lot en cause.
  failure,
}

@freezed
abstract class StudentErasureState with _$StudentErasureState {
  const factory StudentErasureState({
    @Default(StudentErasureStatus.idle) StudentErasureStatus status,
    @Default(StudentPurgePreview()) StudentPurgePreview preview,

    /// Un effacement de cet élève est commencé et n'est pas terminé.
    @Default(false) bool inProgress,

    /// Les données sont dans le club (effacement par lots) et non sur
    /// l'appareil.
    @Default(false) bool synchronized,
    @Default(0) int done,
    @Default(0) int total,
    Failure? failure,
  }) = _StudentErasureState;
}
