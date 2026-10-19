import 'dart:async';

import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_student_sheet.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/live_reload.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'student_sheet_bloc.freezed.dart';
part 'student_sheet_event.dart';
part 'student_sheet_state.dart';

/// La fiche d'un élève : progression par bloc, courbes, exercice suivant.
///
/// **Temps réel (FB5b)** : une fois ouverte, la fiche suit les données dont
/// elle dépend (`WatchStudentSheet`) et se recharge **en place**, sans état de
/// chargement, quand elles changent (un autre appareil a saisi un passage,
/// marqué un bloc acquis ou un « Vu »). Un seul abonnement, fermé avec le
/// bloc ; un échec (accès retiré) s'affiche comme à un chargement ordinaire,
/// et « Réessayer » rouvre l'écoute.
@injectable
class StudentSheetBloc extends Bloc<StudentSheetEvent, StudentSheetState> {
  StudentSheetBloc(this._getSheet, this._watch)
    : super(const StudentSheetState()) {
    on<StudentSheetStarted>(_onStarted);
    on<StudentSheetRefreshed>(_onRefreshed);
    on<StudentSheetChanged>(_onChanged);
  }

  final GetStudentSheet _getSheet;
  final WatchStudentSheet _watch;
  LiveReload? _live;
  StudentId? _followed;

  Future<void> _onStarted(
    StudentSheetStarted event,
    Emitter<StudentSheetState> emit,
  ) async {
    emit(StudentSheetState(studentId: event.studentId));
    // L'abonnement précède la lecture : un changement entre les deux est lu.
    _follow(event.studentId, restart: false);
    await _load(event.studentId, emit);
  }

  Future<void> _onRefreshed(
    StudentSheetRefreshed event,
    Emitter<StudentSheetState> emit,
  ) async {
    final id = state.studentId;
    if (id == null) return;
    _follow(id, restart: state.status == StudentSheetStatus.failure);
    await _load(id, emit);
  }

  Future<void> _onChanged(
    StudentSheetChanged event,
    Emitter<StudentSheetState> emit,
  ) async {
    try {
      final id = state.studentId;
      if (id != null) await _load(id, emit);
    } finally {
      event.done.complete();
    }
  }

  void _follow(StudentId id, {required bool restart}) {
    if (_followed != id) {
      // Un autre élève : l'écoute de l'ancien se ferme, une neuve s'ouvre.
      unawaited(_live?.stop());
      _live = null;
      _followed = id;
    }
    final live = _live ??= LiveReload(
      open: () => _watch(id),
      reload: _requestReload,
    );
    if (restart) {
      live.restart();
    } else {
      live.start();
    }
  }

  Future<void> _requestReload() {
    if (isClosed) return Future.value();
    final done = Completer<void>();
    add(StudentSheetEvent.changed(done: done));
    return done.future;
  }

  @override
  Future<void> close() async {
    await _live?.stop();
    await super.close();
  }

  Future<void> _load(StudentId id, Emitter<StudentSheetState> emit) async {
    switch (await _getSheet(id)) {
      case Ok(:final value):
        emit(
          StudentSheetState(
            status: StudentSheetStatus.ready,
            studentId: id,
            sheet: value,
          ),
        );
      case Err(:final failure):
        emit(
          StudentSheetState(
            status: StudentSheetStatus.failure,
            studentId: id,
            failure: failure,
          ),
        );
    }
  }
}
