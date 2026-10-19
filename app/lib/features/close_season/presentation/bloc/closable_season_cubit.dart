import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/close_season/domain/get_closable_season.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// La saison à proposer de clore sur « Aujourd'hui » (U11-15) : `null` tant
/// qu'aucune saison terminée n'est ouverte.
@injectable
class ClosableSeasonCubit extends Cubit<Season?> {
  ClosableSeasonCubit(this._find, this._clock) : super(null);

  final GetClosableSeason _find;
  final Clock _clock;

  Future<void> load() async {
    final season = await _find(today: _clock.today());
    // Page quittée pendant la lecture (lente sur le serveur) : rien à dire.
    if (!isClosed) emit(season);
  }
}
