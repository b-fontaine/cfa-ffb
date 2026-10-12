part of 'exercise_sheet_bloc.dart';

@freezed
sealed class ExerciseSheetEvent with _$ExerciseSheetEvent {
  const factory ExerciseSheetEvent.started({required ExerciseRef exercise}) =
      ExerciseSheetStarted;
}
