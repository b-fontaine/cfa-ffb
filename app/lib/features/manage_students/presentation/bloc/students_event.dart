part of 'students_bloc.dart';

@freezed
sealed class StudentsEvent with _$StudentsEvent {
  const factory StudentsEvent.started() = StudentsStarted;

  const factory StudentsEvent.refreshed() = StudentsRefreshed;

  /// Les données de la liste ont changé (cet appareil ou un autre) : relecture
  /// en place, sans état de chargement. `done` est complété à la fin de la
  /// relecture (voir `LiveReload`).
  const factory StudentsEvent.changed({required Completer<void> done}) =
      StudentsChanged;
}
