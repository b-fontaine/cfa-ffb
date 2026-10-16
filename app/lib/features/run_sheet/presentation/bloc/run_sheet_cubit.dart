import 'dart:async';

import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_sheet_cubit.freezed.dart';
part 'run_sheet_state.dart';

/// Séance guidée : étape courante, compteurs locaux, score du jeu et minuteur
/// indicatif.
///
/// Tout est local et jamais enregistré. Toutes les étapes sont atteignables
/// librement, sans élèves ni séance planifiée ni saisie : on peut relire la
/// séance entière. Le cubit est conservé par `RunSheetSessions` (clé =
/// séance, public, séance planifiée) pour survivre à un aller-retour par la
/// saisie des résultats ; [finish] le réinitialise et `RunSheetSessions`
/// le libère.
class RunSheetCubit extends Cubit<RunSheetState> {
  RunSheetCubit(this._resolve, this._ticker, this.key)
    : super(const RunSheetState());

  final ResolveRunPlan _resolve;
  final RunTicker _ticker;
  final RunKey key;

  StreamSubscription<void>? _ticks;
  bool _loadStarted = false;
  int? _requestedStep;

  /// Synchronise le cubit avec l'adresse de la séance guidée : [step] est
  /// l'étape demandée (`?step=`), `null` quand la séance vient d'être lancée.
  ///
  /// Sans étape et avec de la progression conservée, la reprise est proposée
  /// ([RunSheetState.resumeOffered]) au lieu de repartir silencieusement de
  /// l'ancienne étape. Idempotent : appelé à chaque reconstruction de la
  /// route, il ne change rien de plus la deuxième fois.
  Future<void> syncFromRoute({int? step}) async {
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
    emit(state.copyWith(status: RunStatus.loading, failure: null));
    final result = await _resolve(
      key.sheetId,
      audience: key.audience,
      sessionId: key.sessionId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: RunStatus.ready,
            plan: value,
            step: value.clamp(_requestedStep ?? state.step),
          ),
        );
      case Err(failure: NotFound()):
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

  /// Fin de séance : remet à zéro étape, compteurs, score et minuteur ; le
  /// déroulé reste chargé. Rien n'est écrit.
  Future<void> finish() async {
    _requestedStep = null;
    emit(RunSheetState(status: state.status, plan: state.plan));
    await _stopTicks();
  }

  Future<void> _stopTicks() async {
    final cancelled = _ticks?.cancel();
    _ticks = null;
    await cancelled;
  }

  @override
  Future<void> close() async {
    await _stopTicks();
    await super.close();
  }
}
