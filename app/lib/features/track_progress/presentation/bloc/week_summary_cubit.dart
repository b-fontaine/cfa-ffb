import 'package:billard_cfa/features/track_progress/domain/get_week_summary.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'week_summary_cubit.freezed.dart';

enum WeekStatus { loading, ready, failure }

@freezed
abstract class WeekSummaryState with _$WeekSummaryState {
  const factory WeekSummaryState({
    @Default(WeekStatus.loading) WeekStatus status,
    WeekSummary? summary,
    Failure? failure,
  }) = _WeekSummaryState;
}

/// Section « 7 derniers jours » de l'accueil.
@injectable
class WeekSummaryCubit extends Cubit<WeekSummaryState> {
  WeekSummaryCubit(this._get) : super(const WeekSummaryState());

  final GetWeekSummary _get;

  /// (Re)charge la section ; sert aussi de « Réessayer ».
  Future<void> load() async {
    if (state.status != WeekStatus.loading) emit(const WeekSummaryState());
    final result = await _get();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => WeekSummaryState(
        status: WeekStatus.ready,
        summary: value,
      ),
      Err(:final failure) => WeekSummaryState(
        status: WeekStatus.failure,
        failure: failure,
      ),
    });
  }
}
