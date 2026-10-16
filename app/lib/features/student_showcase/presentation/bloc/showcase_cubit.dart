import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'showcase_cubit.freezed.dart';

enum ShowcaseStatus { loading, ready, failure }

@freezed
abstract class ShowcaseState with _$ShowcaseState {
  const factory ShowcaseState({
    @Default(ShowcaseStatus.loading) ShowcaseStatus status,
    StudentShowcase? showcase,
    Failure? failure,
  }) = _ShowcaseState;
}

/// La vue « à montrer à l'élève » : charge le prénom et le parcours.
@injectable
class ShowcaseCubit extends Cubit<ShowcaseState> {
  ShowcaseCubit(this._get) : super(const ShowcaseState());

  final GetStudentShowcase _get;

  /// (Re)charge la vue de l'élève ; sert aussi de « Réessayer ».
  Future<void> load(StudentId studentId) async {
    if (state.status != ShowcaseStatus.loading) {
      emit(const ShowcaseState());
    }
    final result = await _get(studentId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => ShowcaseState(
        status: ShowcaseStatus.ready,
        showcase: value,
      ),
      Err(:final failure) => ShowcaseState(
        status: ShowcaseStatus.failure,
        failure: failure,
      ),
    });
  }
}
