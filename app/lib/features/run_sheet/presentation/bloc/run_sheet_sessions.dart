import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:injectable/injectable.dart';

/// Les séances guidées en cours, par clé (séance, public, séance planifiée).
///
/// Vit au-dessus du routeur : la navigation par `context.go` retire la page
/// du guide, ce qui détruirait un cubit fourni par la route elle-même. Les
/// compteurs locaux survivent ainsi à un aller-retour par la saisie des
/// résultats. Ils ne s'accumulent pas : [release] ferme et retire un cubit
/// (« Terminer la séance »), et au plus [maxRunning] séances restent en
/// cours, la moins récemment utilisée étant évincée.
@lazySingleton
class RunSheetSessions {
  RunSheetSessions(this._resolve, this._ticker);

  /// Nombre maximal de séances guidées gardées en même temps.
  static const maxRunning = 4;

  final ResolveRunPlan _resolve;
  final RunTicker _ticker;

  /// Dans l'ordre d'utilisation : la plus ancienne en premier.
  final Map<RunKey, RunSheetCubit> _running = {};

  /// Les clés des séances en cours, de la moins à la plus récemment utilisée.
  List<RunKey> get runningKeys => List.unmodifiable(_running.keys);

  /// Le cubit de [key], créé à la première demande ; il devient le plus
  /// récemment utilisé.
  RunSheetCubit of(RunKey key) {
    final existing = _running.remove(key);
    final cubit = existing ?? RunSheetCubit(_resolve, _ticker, key);
    _running[key] = cubit;
    while (_running.length > maxRunning) {
      final oldest = _running.keys.first;
      final evicted = _running.remove(oldest)!;
      evicted.close().ignore();
    }
    return cubit;
  }

  /// Ferme et retire le cubit de [key] (fin de séance) ; sans effet s'il n'y
  /// en a pas.
  Future<void> release(RunKey key) async {
    final cubit = _running.remove(key);
    if (cubit != null) await cubit.close();
  }

  /// Ferme tous les cubits (fin du graphe de dépendances).
  @disposeMethod
  Future<void> dispose() async {
    final cubits = _running.values.toList();
    _running.clear();
    for (final cubit in cubits) {
      await cubit.close();
    }
  }
}
