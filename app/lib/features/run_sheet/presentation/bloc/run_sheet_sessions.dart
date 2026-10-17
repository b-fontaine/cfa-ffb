import 'dart:async';

import 'package:billard_cfa/entities/run_progress/domain/run_progress_links.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_progress_keeper.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Les séances guidées en cours, par clé (séance, public, séance planifiée).
///
/// Vit au-dessus du routeur : la navigation par `context.go` retire la page
/// du guide, ce qui détruirait un cubit fourni par la route elle-même. Les
/// compteurs locaux survivent ainsi à un aller-retour par la saisie des
/// résultats. Ils ne s'accumulent pas : [release] ferme et retire un cubit
/// (« Terminer la séance »), et au plus [maxRunning] séances restent en
/// cours, la moins récemment utilisée étant évincée.
///
/// L'état de chaque séance est aussi gardé sur l'appareil (ADR 0020) :
/// [restore] le remet en place au démarrage, [release] et l'éviction
/// l'oublient, [dispose] le garde pour le prochain lancement. Quand un élève
/// est effacé, les guides liés à son groupe, à sa saisie ou à sa séance
/// planifiée sont libérés et leur état oublié, sans qu'aucune écriture ne le
/// recrée (droit à l'effacement, ADR 0020 § 7).
@lazySingleton
class RunSheetSessions {
  RunSheetSessions(this._resolve, this._ticker, this._keeper) {
    _listenToErasures();
  }

  /// Nombre maximal de séances guidées gardées en même temps.
  static const maxRunning = 4;

  final ResolveRunPlan _resolve;
  final RunTicker _ticker;
  final RunProgressKeeper _keeper;

  StreamSubscription<RunProgressLinks>? _erasures;
  bool _restoreStarted = false;
  Future<void>? _restoring;

  /// Dans l'ordre d'utilisation : la plus ancienne en premier.
  final Map<RunKey, RunSheetCubit> _running = {};

  /// Les clés des séances en cours, de la moins à la plus récemment utilisée.
  List<RunKey> get runningKeys => List.unmodifiable(_running.keys);

  /// Les séances commencées (guide prêt avec de la progression), de la plus
  /// récemment utilisée à la plus ancienne. Lecture seule : ne crée rien et
  /// ne change pas l'ordre d'utilisation.
  List<RunningSession> snapshot() => [
    for (final entry in _running.entries.toList().reversed)
      ?_runningOf(entry.key, entry.value.state),
  ];

  static RunningSession? _runningOf(RunKey key, RunSheetState state) {
    final plan = state.plan;
    if (state.status != RunStatus.ready || plan == null || !state.hasProgress) {
      return null;
    }
    final step = plan.clamp(state.step);
    return RunningSession(
      key: key,
      step: step,
      stepCount: plan.stepCount,
      phase: plan.steps[step].phase,
      sheetTitle: plan.sheet.title,
      part: plan.sheet.part,
      partCount: plan.partCount,
      plannedGroupId: plan.planned?.groupId,
      plannedDate: plan.planned?.date,
    );
  }

  void _listenToErasures() {
    if (_erasures != null) return;
    _erasures = _keeper.erasures.listen(_onErased);
  }

  /// La restauration en cours, `null` quand il n'y en a pas : l'accueil
  /// l'attend avant de lister les séances commencées.
  Future<void>? get restoring => _restoring;

  /// Le cubit de [key], créé à la première demande ; il devient le plus
  /// récemment utilisé.
  RunSheetCubit of(RunKey key) {
    final existing = _running.remove(key);
    final cubit = existing ?? RunSheetCubit(_resolve, _ticker, key, _keeper);
    _running[key] = cubit;
    while (_running.length > maxRunning) {
      final oldest = _running.keys.first;
      final evicted = _running.remove(oldest)!;
      // Le plafond est une règle d'usage : la séance évincée n'est pas
      // gardée sur l'appareil.
      unawaited(evicted.discard().whenComplete(evicted.close));
    }
    return cubit;
  }

  /// Remet en place, au démarrage, les séances guidées gardées sur l'appareil
  /// (ADR 0020 § 5.2). Une seule fois par graphe de dépendances ; ne bloque
  /// pas l'ouverture de l'application, et ne lève jamais : un stockage
  /// illisible donne simplement un guide neuf.
  ///
  /// Les séances de plus de sept jours sont oubliées, seules les
  /// [maxRunning] plus récentes sont gardées, et celles dont la séance du
  /// catalogue ou la séance planifiée n'existe plus sont oubliées. Un guide
  /// déjà ouvert par la route reste le seul cubit de sa clé et le plus récent.
  Future<void> restore() async {
    if (_restoreStarted) {
      await _restoring;
      return;
    }
    _restoreStarted = true;
    _listenToErasures();
    final restoring = _restore();
    _restoring = restoring;
    try {
      await restoring;
    } finally {
      _restoring = null;
    }
  }

  Future<void> _restore() async {
    try {
      await _keeper.purgeStale();
      final saved = await _keeper.all();
      // Ce qui reste de place après les guides ouverts entre-temps.
      final room = maxRunning - _running.length;
      final kept = saved
          .where((p) => !_running.containsKey(RunKey.fromProgress(p.key)))
          .take(room < 0 ? 0 : room)
          .toList();
      for (final extra in saved) {
        if (!kept.contains(extra) &&
            !_running.containsKey(RunKey.fromProgress(extra.key))) {
          await _keeper.forget(extra.key);
        }
      }
      // Les restaurées précèdent les guides déjà ouverts (plus récents).
      final restored = <RunKey, RunSheetCubit>{
        for (final progress in kept.reversed)
          RunKey.fromProgress(progress.key): RunSheetCubit(
            _resolve,
            _ticker,
            RunKey.fromProgress(progress.key),
            _keeper,
          ),
      };
      final opened = Map.of(_running);
      _running
        ..clear()
        ..addAll(restored)
        ..addAll(opened);
      await Future.wait([for (final cubit in restored.values) cubit.load()]);
      for (final entry in restored.entries) {
        // Un guide évincé ou libéré pendant le chargement est déjà fermé, et
        // sa clé a pu être reprise par un autre : on n'y touche plus.
        if (entry.value.isClosed ||
            !identical(_running[entry.key], entry.value)) {
          continue;
        }
        // Séance introuvable, ou plus rien à reprendre (séance planifiée
        // supprimée…) : le guide a déjà oublié son état, on ne le garde pas.
        final state = entry.value.state;
        if (state.status == RunStatus.notFound || !state.hasProgress) {
          _running.remove(entry.key);
          await entry.value.close();
        }
      }
    } on Object catch (error, stackTrace) {
      // Le démarrage ne dépend pas de la reprise : un guide neuf suffit. La
      // cause est signalée, jamais relancée (ADR 0020 D10).
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'run_sheet_sessions',
          context: ErrorDescription('while restoring the running sessions'),
        ),
      );
    }
  }

  /// Libère les guides touchés par l'effacement [links] : leur état gardé est
  /// effacé (sans qu'une écriture en vol le recrée) puis ils sont fermés.
  Future<void> _onErased(RunProgressLinks links) async {
    final touched = [
      for (final entry in _running.entries.toList())
        if (links.touches(
          entry.key.progressKey,
          recordId: entry.value.state.recordChoice?.recordId,
        ))
          entry.key,
    ];
    final cubits = [for (final key in touched) _running.remove(key)!];
    for (final cubit in cubits) {
      await cubit.erase();
      await cubit.close();
    }
  }

  /// Ferme et retire le cubit de [key] (fin de séance ou abandon) et oublie
  /// son état gardé sur l'appareil ; sans effet s'il n'y en a pas.
  Future<void> release(RunKey key) async {
    final cubit = _running.remove(key);
    if (cubit == null) return;
    await cubit.discard();
    await cubit.close();
  }

  /// Ferme tous les cubits (fin du graphe de dépendances). L'état gardé sur
  /// l'appareil reste : c'est lui que [restore] relira au prochain lancement.
  @disposeMethod
  Future<void> dispose() async {
    // Une restauration en cours finit avant de vider le registre : sinon elle
    // y réinsérerait des guides qu'on vient de fermer.
    await _restoring;
    // Pas attendu : l'annulation d'un abonnement ne se termine pas dans la
    // zone simulée des tests de widgets.
    unawaited(_erasures?.cancel());
    _erasures = null;
    _restoreStarted = false;
    final cubits = _running.values.toList();
    _running.clear();
    for (final cubit in cubits) {
      await cubit.close();
    }
  }
}
