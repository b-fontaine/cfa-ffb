import 'dart:async';
import 'dart:math' as math;

import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/features/run_sheet/domain/reconcile_run_progress.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_progress_keeper.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_timer.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/timer_tone.dart';
import 'package:flutter/foundation.dart' show mapEquals, setEquals;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_sheet_cubit.freezed.dart';
part 'run_sheet_state.dart';

/// Séance guidée : étape courante, compteurs locaux, score du jeu et minuteur
/// indicatif.
///
/// Rien de tout cela n'entre dans le suivi des élèves. Toutes les étapes sont
/// atteignables librement, sans élèves ni séance planifiée ni saisie : on peut
/// relire la séance entière. Le cubit est conservé par `RunSheetSessions`
/// (clé = séance, public, séance planifiée) pour survivre à un aller-retour
/// par la saisie des résultats ; [finish] le réinitialise et
/// `RunSheetSessions` le libère.
///
/// L'état de la séance en cours est aussi **gardé sur l'appareil** (ADR 0020,
/// lot 10b) pour survivre à un rechargement ou à la fermeture de
/// l'application : étape, compteurs, grille, score, minuteur (restauré en
/// pause) et identifiant de la saisie ouverte. Les écritures se font à la
/// suite les unes des autres, la dernière gagne, et un échec d'écriture ne
/// bloque jamais le guide (il est signalé à l'observateur de blocs).
class RunSheetCubit extends Cubit<RunSheetState> {
  RunSheetCubit(this._resolve, this._ticker, this.key, this._keeper)
    : super(RunSheetState(mode: _defaultMode(key)));

  /// Le minuteur n'est écrit que toutes les [timerCheckpointSeconds]
  /// secondes (une écriture par seconde serait inutile) : un rechargement perd
  /// au plus ce délai. La pause et le changement de phase écrivent à l'instant.
  static const timerCheckpointSeconds = 10;

  /// Mode d'ouverture de [key] : « Mener » pour une séance planifiée.
  static RunMode _defaultMode(RunKey key) =>
      RunMode.defaultFor(planned: key.sessionId != null);

  final ResolveRunPlan _resolve;
  final RunTicker _ticker;
  final RunKey key;
  final RunProgressKeeper _keeper;

  StreamSubscription<void>? _ticks;
  bool _loadStarted = false;
  int? _requestedStep;

  /// Lecture de l'état enregistré, faite une seule fois (avant le déroulé).
  Future<void>? _hydration;

  /// Une ligne enregistrée existe et doit être réécrite à l'arrivée du
  /// déroulé (la saisie qu'elle nommait n'existe plus).
  bool _rewriteOnReady = false;

  /// Vrai si une ligne était enregistrée pour cette clé au démarrage.
  bool _hadSaved = false;

  /// L'état gardé a été effacé de force (droit à l'effacement) : plus aucune
  /// écriture ne doit le recréer.
  bool _erased = false;

  /// Dernière écriture demandée : les suivantes l'attendent.
  Future<void> _writes = Future<void>.value();

  /// Mode à reporter dans l'adresse (`?mode=`) : `null` tant qu'il est celui
  /// d'ouverture de la clé (l'adresse reste courte et le défaut s'applique à
  /// la relecture du lien).
  RunMode? get routeMode => state.mode == _defaultMode(key) ? null : state.mode;

  /// Change le mode du guide ; sans effet s'il est déjà celui-là.
  void modeChanged(RunMode mode) {
    if (mode == state.mode) return;
    emit(state.copyWith(mode: mode));
  }

  /// Synchronise le cubit avec l'adresse de la séance guidée : [step] est
  /// l'étape demandée (`?step=`), `null` quand la séance vient d'être lancée ;
  /// [mode] est le mode demandé (`?mode=`), `null` pour garder celui du guide.
  ///
  /// Sans étape et avec de la progression conservée, la reprise est proposée
  /// ([RunSheetState.resumeOffered]) au lieu de repartir silencieusement de
  /// l'ancienne étape. Idempotent : appelé à chaque reconstruction de la
  /// route, il ne change rien de plus la deuxième fois.
  Future<void> syncFromRoute({int? step, RunMode? mode}) async {
    // L'état enregistré d'abord : la reprise se propose sur ce qu'il contient.
    await _hydrate();
    if (isClosed) return;
    if (mode != null) modeChanged(mode);
    if (step != null) {
      showStep(step);
      if (state.resumeOffered) emit(state.copyWith(resumeOffered: false));
    } else if (state.hasProgress && !state.resumeOffered) {
      emit(state.copyWith(resumeOffered: true));
    }
    await load();
  }

  /// Retient la saisie des résultats ouverte depuis ce guide ([recordId]),
  /// son groupe, sa date et ses absents : ils sont proposés à l'exercice
  /// suivant sans les redemander, et [recordId] mène au bilan à « Terminer ».
  void recordChosen({
    required SessionId recordId,
    required GroupId group,
    required DateTime date,
    required Set<StudentId> absent,
  }) {
    if (isClosed) return;
    emit(
      state.copyWith(
        recordChoice: (
          recordId: recordId,
          group: group,
          date: date,
          absent: absent,
        ),
      ),
    );
  }

  /// Fixe les étiquettes de la note de jeu (liste fermée, ADR 0023) ; elles
  /// remplacent les précédentes et sont gardées avec la séance en cours.
  void tagsChanged(Set<SessionTag> tags) {
    if (isClosed || setEquals(tags, state.tags)) return;
    emit(state.copyWith(tags: Set.unmodifiable(tags), tagsNotSaved: false));
  }

  /// Reprend la séance là où elle en était.
  void resume() {
    if (state.resumeOffered) emit(state.copyWith(resumeOffered: false));
  }

  /// Recommence la séance : compteurs, score, minuteur et étape à zéro.
  Future<void> restart() => finish();

  /// Charge le déroulé une seule fois (relance possible après un échec).
  Future<void> load() async {
    if (_loadStarted && state.status != RunStatus.failure) return;
    _loadStarted = true;
    await _hydrate();
    if (isClosed) return;
    emit(state.copyWith(status: RunStatus.loading, failure: null));
    final result = await _resolve(
      key.sheetId,
      audience: key.audience,
      sessionId: key.sessionId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        // Une séance planifiée supprimée depuis l'enregistrement : le guide
        // s'ouvre à neuf (la fiche, elle, existe) et l'état gardé est oublié.
        final orphaned =
            _hadSaved && isOrphanedProgress(key.progressKey, value);
        if (orphaned) _enqueue(() => _keeper.forget(key.progressKey));
        final base = orphaned ? RunSheetState(mode: state.mode) : state;
        // L'état enregistré est ramené à la séance telle qu'elle est
        // aujourd'hui (fiche raccourcie, initiation disparue…).
        final fitted = reconcileRunProgress(
          RunProgress(
            key: key.progressKey,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            step: math.max(0, _requestedStep ?? base.step),
            counts: base.counts,
            checked: base.checked,
          ),
          value,
        );
        final next = base.copyWith(
          status: RunStatus.ready,
          plan: value,
          step: fitted.step,
          counts: fitted.counts,
          checked: fitted.checked,
        );
        emit(
          next.copyWith(resumeOffered: next.resumeOffered && next.hasProgress),
        );
      case Err(failure: NotFound()):
        // Une séance planifiée supprimée, une fiche retirée : rien à reprendre.
        if (_hadSaved) _enqueue(() => _keeper.forget(key.progressKey));
        emit(state.copyWith(status: RunStatus.notFound));
      case Err(:final failure):
        emit(state.copyWith(status: RunStatus.failure, failure: failure));
    }
  }

  /// Va à [step] (ramené dans la plage). Avant la fin du chargement, la
  /// demande est gardée et appliquée à l'arrivée du déroulé.
  void showStep(int step) {
    final plan = state.plan;
    if (plan == null) {
      _requestedStep = step;
      return;
    }
    final target = plan.clamp(step);
    if (target == state.step) return;
    final changesPhase =
        plan.steps[target].phase != plan.steps[state.step].phase;
    emit(
      state.copyWith(
        step: target,
        timerSeconds: changesPhase ? 0 : state.timerSeconds,
      ),
    );
  }

  /// Ajoute [delta] (+1 ou -1) au compteur de l'initiation [initiationId],
  /// borné de 0 au nombre d'essais.
  void countChanged(String initiationId, int delta) {
    final scoring = state.plan?.sheet.initiation
        .where((i) => i.id == initiationId)
        .firstOrNull
        ?.scoring;
    if (scoring is! CounterScoring) return;
    final current = state.counts[initiationId] ?? 0;
    final updated = (current + delta).clamp(0, scoring.of);
    if (updated == current) return;
    emit(state.copyWith(counts: {...state.counts, initiationId: updated}));
  }

  /// Coche ou décoche le critère [index] de l'initiation [initiationId].
  void criterionToggled(String initiationId, int index) {
    final current = state.checked[initiationId] ?? const <int>{};
    final updated = current.contains(index)
        ? ({...current}..remove(index))
        : {...current, index};
    emit(state.copyWith(checked: {...state.checked, initiationId: updated}));
  }

  /// Ajoute [delta] au score du camp [side], jamais sous zéro.
  void scoreChanged(ScoreSide side, int delta) {
    switch (side) {
      case ScoreSide.a:
        emit(state.copyWith(scoreA: (state.scoreA + delta).clamp(0, 999)));
      case ScoreSide.b:
        emit(state.copyWith(scoreB: (state.scoreB + delta).clamp(0, 999)));
    }
  }

  /// Démarre ou met en pause le minuteur de la phase courante.
  void timerToggled() {
    if (state.timerRunning) {
      unawaited(_stopTicks());
      emit(state.copyWith(timerRunning: false));
      return;
    }
    _ticks = _ticker.ticks().listen(
      (_) => emit(state.copyWith(timerSeconds: state.timerSeconds + 1)),
    );
    emit(state.copyWith(timerRunning: true));
  }

  void timerReset() => emit(state.copyWith(timerSeconds: 0));

  /// Arrête le minuteur sans toucher au reste (la page du guide n'est plus
  /// active : il ne doit pas tourner dans le vide).
  Future<void> timerPaused() async {
    if (isClosed || !state.timerRunning) return;
    await _stopTicks();
    if (isClosed) return;
    emit(state.copyWith(timerRunning: false));
  }

  /// « Terminer » : donne les étiquettes à la saisie ouverte depuis ce guide
  /// (s'il y en a une et si des étiquettes sont choisies), puis [finish].
  ///
  /// Sans saisie ouverte, les étiquettes n'ont nulle part où aller : elles
  /// sont oubliées avec la séance (le guide le dit à l'animateur). Si
  /// l'écriture échoue, la séance n'est **pas** terminée : l'échec est
  /// signalé à l'observateur de blocs et dans l'état (`tagsNotSaved`), et
  /// rend `false`. « Recommencer » passe par [finish] : il ne donne rien.
  Future<bool> endSession() async {
    final record = state.recordChoice?.recordId;
    final tags = state.tags;
    if (record != null && tags.isNotEmpty) {
      try {
        await _keeper.giveTags(record, tags);
      } on Object catch (error, stackTrace) {
        onError(error, stackTrace);
        if (!isClosed) emit(state.copyWith(tagsNotSaved: true));
        return false;
      }
    }
    await finish();
    return true;
  }

  /// Fin de séance : remet à zéro étape, compteurs, score, minuteur et mode ;
  /// le déroulé reste chargé. Rien n'est enregistré dans le suivi, et l'état
  /// gardé sur l'appareil est oublié.
  Future<void> finish() async {
    _requestedStep = null;
    emit(
      RunSheetState(
        status: state.status,
        plan: state.plan,
        mode: _defaultMode(key),
      ),
    );
    await _stopTicks();
  }

  /// Oublie l'état gardé sur l'appareil, sans toucher à l'état du cubit
  /// (abandon, éviction) ; rend la main une fois l'effacement terminé.
  Future<void> discard() {
    _enqueue(() => _keeper.forget(key.progressKey));
    return _writes;
  }

  /// Efface l'état gardé de force (droit à l'effacement d'un élève dont ce
  /// guide portait le score ou la saisie) : plus aucune écriture n'est
  /// acceptée, celles déjà demandées vont à leur terme, puis la ligne est
  /// oubliée **après** elles (une écriture en vol ne la recrée pas).
  Future<void> erase() async {
    _erased = true;
    await _writes;
    try {
      await _keeper.forget(key.progressKey);
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }

  /// Remet dans le cubit l'état enregistré de cette séance, une seule fois.
  /// Le déroulé n'est pas encore là : l'état est rapproché de la séance à son
  /// arrivée (voir [load]). Une lecture qui échoue laisse un guide neuf.
  Future<void> _hydrate() => _hydration ??= _readSaved();

  Future<void> _readSaved() async {
    try {
      final saved = await _keeper.saved(key.progressKey);
      if (saved == null || isClosed) return;
      _hadSaved = true;
      final recordId = saved.recordId;
      final link = recordId == null ? null : await _keeper.recordLink(recordId);
      if (isClosed) return;
      _rewriteOnReady = recordId != null && link == null;
      // Le déroulé n'est pas encore là : `onChange` n'écrit rien (ce n'est pas
      // un changement).
      emit(
        state.copyWith(
          step: saved.step,
          counts: saved.counts,
          checked: saved.checked,
          scoreA: saved.scoreA,
          scoreB: saved.scoreB,
          timerSeconds: saved.timerSeconds,
          recordChoice: link,
          tags: saved.tags,
        ),
      );
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }

  @override
  void onChange(Change<RunSheetState> change) {
    super.onChange(change);
    final next = change.nextState;
    // Rien n'est écrit avant que le déroulé soit prêt, donc ni pour la remise
    // en place de l'état enregistré (qui précède le déroulé).
    if (next.plan == null) return;
    final previous = change.currentState;
    final changed = _persistedDiffers(previous, next);
    final checkpoint =
        next.hasProgress &&
        ((previous.timerSeconds != next.timerSeconds &&
                next.timerSeconds % timerCheckpointSeconds == 0) ||
            (previous.timerRunning && !next.timerRunning));
    if (!changed && !checkpoint && !_rewriteOnReady) return;
    _rewriteOnReady = false;
    _persist(next);
  }

  /// Vrai si quelque chose d'enregistré diffère entre [a] et [b] (le minuteur
  /// mis à part).
  static bool _persistedDiffers(RunSheetState a, RunSheetState b) =>
      a.step != b.step ||
      a.scoreA != b.scoreA ||
      a.scoreB != b.scoreB ||
      !setEquals(a.tags, b.tags) ||
      a.recordChoice?.recordId != b.recordChoice?.recordId ||
      !mapEquals(a.counts, b.counts) ||
      !_sameChecked(a.checked, b.checked);

  static bool _sameChecked(Map<String, Set<int>> a, Map<String, Set<int>> b) =>
      a.length == b.length &&
      a.entries.every((e) {
        final other = b[e.key];
        return other != null && setEquals(e.value, other);
      });

  /// Enregistre [state], ou oublie la séance quand il n'y a plus rien à
  /// reprendre.
  void _persist(RunSheetState state) {
    final progressKey = key.progressKey;
    if (!state.hasProgress) {
      _enqueue(() => _keeper.forget(progressKey));
      return;
    }
    final recordId = state.recordChoice?.recordId;
    _enqueue(
      () => _keeper.save(
        key: progressKey,
        step: state.step,
        counts: state.counts,
        checked: state.checked,
        scoreA: state.scoreA,
        scoreB: state.scoreB,
        timerSeconds: state.timerSeconds,
        recordId: recordId,
        tags: state.tags,
      ),
    );
  }

  /// Met [write] à la suite des écritures en attente : jamais deux à la fois,
  /// la dernière demandée est la dernière faite. Un échec est signalé, jamais
  /// propagé (D10).
  void _enqueue(Future<void> Function() write) {
    if (_erased) return;
    _writes = _writes.then((_) => write()).catchError(onError);
  }

  Future<void> _stopTicks() async {
    final cancelled = _ticks?.cancel();
    _ticks = null;
    await cancelled;
  }

  @override
  Future<void> close() async {
    await _stopTicks();
    // Les écritures déjà demandées vont à leur terme sans que la fermeture les
    // attende : un état enregistré ne se perd pas parce que le cubit se ferme
    // (changement de page, mise à jour de l'application). Ceux qui doivent
    // attendre l'effacement le font par [discard].
    await super.close();
  }
}
