import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'students_bloc.freezed.dart';
part 'students_event.dart';
part 'students_state.dart';

/// Les groupes de la saison et leurs élèves (liste, choix d'un groupe).
@injectable
class StudentsBloc extends Bloc<StudentsEvent, StudentsState> {
  StudentsBloc(this._overview, this._clock) : super(const StudentsState()) {
    on<StudentsStarted>(_load);
    on<StudentsRefreshed>(_load);
  }

  final GetClubOverview _overview;
  final Clock _clock;

  Future<void> _load(StudentsEvent event, Emitter<StudentsState> emit) async {
    emit(state.copyWith(status: StudentsStatus.loading));
    switch (await _overview(today: _clock.today())) {
      case Ok(:final value):
        emit(StudentsState(status: StudentsStatus.ready, club: value));
      case Err(:final failure):
        emit(StudentsState(status: StudentsStatus.failure, failure: failure));
    }
  }
}
