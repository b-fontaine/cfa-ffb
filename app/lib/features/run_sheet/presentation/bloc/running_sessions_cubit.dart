import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Séances guidées commencées de l'accueil, de la plus récente à la plus
/// ancienne. Lecture seule, sauf l'abandon explicite.
@injectable
class RunningSessionsCubit extends Cubit<List<RunningSession>> {
  RunningSessionsCubit(this._sessions) : super(const []);

  final RunSheetSessions _sessions;

  /// Relit le registre des séances guidées.
  void refresh() => emit(List.unmodifiable(_sessions.snapshot()));

  /// Abandonne la séance de [key] : le guide est libéré.
  Future<void> abandon(RunKey key) async {
    await _sessions.release(key);
    if (!isClosed) refresh();
  }
}
