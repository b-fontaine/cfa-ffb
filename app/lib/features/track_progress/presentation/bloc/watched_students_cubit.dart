import 'package:billard_cfa/features/track_progress/domain/list_watched_students.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_list.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'watched_students_cubit.freezed.dart';

enum WatchedStatus { loading, ready, failure }

@freezed
abstract class WatchedStudentsState with _$WatchedStudentsState {
  const factory WatchedStudentsState({
    @Default(WatchedStatus.loading) WatchedStatus status,
    @Default(WatchList()) WatchList watchList,
    Failure? failure,
  }) = _WatchedStudentsState;
}

/// Section « À surveiller » de l'accueil.
@injectable
class WatchedStudentsCubit extends Cubit<WatchedStudentsState> {
  WatchedStudentsCubit(this._list) : super(const WatchedStudentsState());

  final ListWatchedStudents _list;

  /// (Re)charge la section ; sert aussi de « Réessayer ».
  Future<void> load() async {
    if (state.status != WatchedStatus.loading) {
      emit(const WatchedStudentsState());
    }
    final result = await _list();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => WatchedStudentsState(
        status: WatchedStatus.ready,
        watchList: value,
      ),
      Err(:final failure) => WatchedStudentsState(
        status: WatchedStatus.failure,
        failure: failure,
      ),
    });
  }
}
