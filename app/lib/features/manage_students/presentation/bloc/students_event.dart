part of 'students_bloc.dart';

@freezed
sealed class StudentsEvent with _$StudentsEvent {
  const factory StudentsEvent.started() = StudentsStarted;

  const factory StudentsEvent.refreshed() = StudentsRefreshed;
}
