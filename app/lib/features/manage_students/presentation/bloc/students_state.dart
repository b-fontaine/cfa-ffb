part of 'students_bloc.dart';

enum StudentsStatus { loading, ready, failure }

@freezed
abstract class StudentsState with _$StudentsState {
  const factory StudentsState({
    @Default(StudentsStatus.loading) StudentsStatus status,
    ClubOverview? club,
    Failure? failure,
  }) = _StudentsState;
}
