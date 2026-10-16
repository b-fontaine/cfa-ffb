import 'package:billard_cfa/features/suggest_session/domain/next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_next_sheet.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'next_sheet_cubit.freezed.dart';

enum NextSheetStatus { loading, ready, failure }

@freezed
abstract class NextSheetState with _$NextSheetState {
  const factory NextSheetState({
    @Default(NextSheetStatus.loading) NextSheetStatus status,
    NextSheet? next,
    Failure? failure,
  }) = _NextSheetState;
}

/// La séance suivante proposée, chargée quand le bilan est prêt.
@injectable
class NextSheetCubit extends Cubit<NextSheetState> {
  NextSheetCubit(this._suggest) : super(const NextSheetState());

  final SuggestNextSheet _suggest;

  Future<void> load({
    required GroupId groupId,
    required Set<StudentId> present,
  }) async {
    if (state.status != NextSheetStatus.loading) emit(const NextSheetState());
    final result = await _suggest(groupId: groupId, present: present);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => NextSheetState(
        status: NextSheetStatus.ready,
        next: value,
      ),
      Err(:final failure) => NextSheetState(
        status: NextSheetStatus.failure,
        failure: failure,
      ),
    });
  }
}
