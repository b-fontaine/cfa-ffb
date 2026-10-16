import 'package:billard_cfa/features/track_seasons/domain/closed_season.dart';
import 'package:billard_cfa/features/track_seasons/domain/list_season_archives.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'season_archives_cubit.freezed.dart';

enum SeasonArchivesStatus { loading, ready, failure }

@freezed
abstract class SeasonArchivesState with _$SeasonArchivesState {
  const factory SeasonArchivesState({
    @Default(SeasonArchivesStatus.loading) SeasonArchivesStatus status,
    @Default(<ClosedSeason>[]) List<ClosedSeason> seasons,
    Failure? failure,
  }) = _SeasonArchivesState;
}

/// L'écran « Saisons passées » : les archives des saisons closes.
@injectable
class SeasonArchivesCubit extends Cubit<SeasonArchivesState> {
  SeasonArchivesCubit(this._list) : super(const SeasonArchivesState());

  final ListSeasonArchives _list;

  Future<void> load() async {
    emit(const SeasonArchivesState());
    switch (await _list()) {
      case Ok(:final value):
        emit(
          SeasonArchivesState(
            status: SeasonArchivesStatus.ready,
            seasons: value,
          ),
        );
      case Err(:final failure):
        emit(
          SeasonArchivesState(
            status: SeasonArchivesStatus.failure,
            failure: failure,
          ),
        );
    }
  }
}
