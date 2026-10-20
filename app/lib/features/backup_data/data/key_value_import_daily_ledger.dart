import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:injectable/injectable.dart';

/// Le compte du jour des écritures d'import, gardé sur l'appareil (stockage
/// clé/valeur, ADR 0024 décision 23) sous l'identifiant du compte : une seule
/// clé par compte, `AAAA-MM-JJ:n`, qui repart de zéro à chaque nouveau jour.
@Environment(Environment.prod)
@LazySingleton(as: ImportDailyLedger)
class KeyValueImportDailyLedger implements ImportDailyLedger {
  KeyValueImportDailyLedger(this._store, this._clock, this._user);

  final KeyValueStore _store;
  final Clock _clock;
  final CurrentUser _user;

  String? get _key {
    final id = _user.id;
    return id == null ? null : 'import.writes.${id.value}';
  }

  String get _today {
    final day = _clock.today();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  @override
  Future<int> spentToday() async {
    final key = _key;
    if (key == null) return 0;
    final stored = await _store.read(key);
    final parts = stored?.split(':');
    if (parts == null || parts.length != 2 || parts.first != _today) return 0;
    return int.tryParse(parts.last) ?? 0;
  }

  @override
  Future<void> add(int writes) async {
    final key = _key;
    if (key == null) return;
    final spent = await spentToday();
    await _store.write(key, '$_today:${spent + writes}');
  }
}
