import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/shared/lib/clock.dart';

/// Le compte du jour en mémoire (tests, scénarios BDD).
final class InMemoryImportDailyLedger implements ImportDailyLedger {
  InMemoryImportDailyLedger(this._clock);

  final Clock _clock;
  DateTime? _day;
  int _spent = 0;

  @override
  Future<int> spentToday() async => _day == _clock.today() ? _spent : 0;

  @override
  Future<void> add(int writes) async {
    final today = _clock.today();
    if (_day != today) {
      _day = today;
      _spent = 0;
    }
    _spent += writes;
  }
}
