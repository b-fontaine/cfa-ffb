part of 'student_form_bloc.dart';

@freezed
sealed class StudentFormEvent with _$StudentFormEvent {
  /// [studentId] `null` : création ; sinon édition de cet élève.
  const factory StudentFormEvent.started({StudentId? studentId}) =
      StudentFormStarted;

  const factory StudentFormEvent.submitted({
    required String firstName,
    required Audience audience,

    /// Nom du groupe créé si le public n'en a pas encore (texte localisé).
    required String groupName,
  }) = StudentFormSubmitted;
}
