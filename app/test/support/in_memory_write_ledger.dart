import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';

/// Le compte du jour des écritures d'une opération, en mémoire (tests,
/// scénarios BDD).
final class InMemoryWriteLedger implements DailyWriteLedger {
  InMemoryWriteLedger(this._clock);

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
