part of 'student_form_bloc.dart';

enum StudentFormStatus { loading, ready, saving, saved, failure }

@freezed
abstract class StudentFormState with _$StudentFormState {
  const factory StudentFormState({
    @Default(StudentFormStatus.loading) StudentFormStatus status,

    /// Élève en cours d'édition ; `null` en création.
    Student? student,

    /// Élève enregistré (statut `saved`).
    Student? saved,
    Failure? failure,
  }) = _StudentFormState;
}
