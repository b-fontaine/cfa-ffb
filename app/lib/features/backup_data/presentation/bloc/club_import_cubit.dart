import 'dart:async';

import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_choices.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/prepare_club_import.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'club_import_cubit.freezed.dart';
part 'club_import_state.dart';

/// Le parcours d'import d'une sauvegarde dans le club (FB7, partie B) : choix
/// du fichier, rapport, correspondance des groupes, séances et élèves sans
/// groupe, confirmations, récapitulatif, exécution par lots, fin.
///
/// Le moteur existe (`PrepareClubImport`, `ClubImportRunner`) : ce cubit ne
/// fait que **conduire l'animateur** et tenir ses décisions ; à chaque
/// décision, le plan est recalculé **sans rien écrire**. Le texte du fichier
/// reste dans ce cubit (jamais dans l'état, jamais journalisé).
///
/// **Reprise** : rien n'est mémorisé ici. Le marqueur du club (propre au
/// compte et au fichier) dit où reprendre ; relancer l'écran avec le même
/// fichier, le même compte et les mêmes choix donne un plan `resumable`.
@Environment(Environment.prod)
@injectable
class ClubImportCubit extends Cubit<ClubImportState> {
  ClubImportCubit(
    this._files,
    this._prepare,
    this._runner,
    this._targets,
    this._scope,
    this._connectivity,
  ) : super(const ClubImportState());

  final BackupFiles _files;
  final PrepareClubImport _prepare;
  final ClubImportRunner _runner;
  final ListImportTargets _targets;
  final ActiveClubScope _scope;
  final ConnectivityStatus _connectivity;

  /// Les limites du moteur (taille des lots, plafond du jour) : les tests les
  /// réduisent pour avoir plusieurs lots ; l'animateur ne les règle jamais.
  @visibleForTesting
  ImportLimits limits = const ImportLimits();

  String? _content;
  bool _stopRequested = false;
  StreamSubscription<bool>? _network;

  /// Ouvre l'écran : rôle effectif, groupes où associer, suivi du réseau (une
  /// exécution interrompue par une coupure reprend au retour du réseau).
  Future<void> started() async {
    _network ??= _connectivity.changes.listen(_onNetwork);
    final role = _scope.role;
    emit(
      state.copyWith(
        role: role,
        canCreateGroups: role != null && ImportActor(role).manages,
        online: _connectivity.online,
      ),
    );
    switch (await _targets()) {
      case Ok(:final value):
        emit(state.copyWith(targets: value));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  void _onNetwork(bool online) {
    if (isClosed) return;
    emit(state.copyWith(online: online));
    if (online && state.run == ClubImportRun.interrupted && !state.busy) {
      unawaited(resume());
    }
  }

  /// Fait choisir un fichier puis calcule le plan (sans écrire).
  Future<void> pickFile() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, failure: null));
    final content = await _files.pick();
    if (content == null) {
      emit(state.copyWith(busy: false));
      return;
    }
    _content = content;
    const decisions = ImportDecisions.none;
    final plan = await _plan(decisions);
    if (plan == null) {
      _content = null;
      return;
    }
    emit(
      state.copyWith(
        busy: false,
        step: ClubImportStep.report,
        plan: plan,
        decisions: decisions,
        // Un import commencé se reprend avec **les mêmes choix** : les groupes
        // déjà écrits n'ont plus de choix à faire, mais le plan ne se reprend
        // que si l'animateur les refait à l'identique.
        groupsNeeded:
            plan.report.undecidedGroups.isNotEmpty ||
            (plan.outline.marker != null && plan.outline.groups.isNotEmpty),
        run: null,
        runFailure: null,
        doneLots: plan.outline.marker?.done ?? 0,
        totalLots: plan.outline.marker?.lots ?? plan.lots.length,
      ),
    );
  }

  /// Le plan pour [decisions] ; `null` (et l'échec dans l'état) si le club ne
  /// se lit pas.
  Future<ClubImportPlan?> _plan(ImportDecisions decisions) async {
    final content = _content;
    if (content == null) {
      _backToFile();
      return null;
    }
    switch (await _prepare(content, decisions: decisions, limits: limits)) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        emit(state.copyWith(busy: false, failure: failure));
        return null;
    }
  }

  Future<void> _decide(ImportDecisions decisions) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, failure: null));
    final plan = await _plan(decisions);
    if (plan == null) return;
    emit(state.copyWith(busy: false, plan: plan, decisions: decisions));
  }

  ImportDecisions _decisions({
    Map<GroupId, GroupChoice>? groups,
    Map<String, OwnerChoice>? sessions,
    Map<StudentId, OwnerChoice>? students,
    Set<GroupId>? merges,
    int? restore,
    int? unverified,
  }) {
    final d = state.decisions;
    return ImportDecisions(
      groups: groups ?? d.groups,
      plannedSessions: sessions ?? d.plannedSessions,
      students: students ?? d.students,
      confirmedMerges: merges ?? d.confirmedMerges,
      restoreConfirmed: restore ?? d.restoreConfirmed,
      unverifiedConfirmed: unverified ?? d.unverifiedConfirmed,
    );
  }

  /// Créer le groupe [fileGroup] du fichier, l'associer à un groupe du club,
  /// ou ne rien choisir (`null`).
  Future<void> chooseGroup(GroupId fileGroup, GroupChoice? choice) {
    final groups = {...state.decisions.groups};
    if (choice == null) {
      groups.remove(fileGroup);
    } else {
      groups[fileGroup] = choice;
    }
    return _decide(_decisions(groups: groups));
  }

  /// Accepte (ou non) que plusieurs groupes du fichier soient fusionnés dans
  /// le groupe [target] du club.
  Future<void> confirmMerge(GroupId target, {required bool confirmed}) {
    final merges = {...state.decisions.confirmedMerges};
    if (confirmed) {
      merges.add(target);
    } else {
      merges.remove(target);
    }
    return _decide(_decisions(merges: merges));
  }

  Future<void> chooseSession(String id, OwnerChoice? choice) {
    final sessions = {...state.decisions.plannedSessions};
    if (choice == null) {
      sessions.remove(id);
    } else {
      sessions[id] = choice;
    }
    return _decide(_decisions(sessions: sessions));
  }

  Future<void> chooseStudent(StudentId id, OwnerChoice? choice) {
    final students = {...state.decisions.students};
    if (choice == null) {
      students.remove(id);
    } else {
      students[id] = choice;
    }
    return _decide(_decisions(students: students));
  }

  /// Confirme (ou retire la confirmation de) le **nombre exact** d'élèves
  /// effacés que l'import rétablirait.
  Future<void> confirmRestore({required bool confirmed}) => _decide(
    _decisions(
      restore: confirmed ? state.plan?.report.restoredStudents ?? 0 : 0,
    ),
  );

  /// Confirme (ou non) le **nombre exact** de fiches qu'un enseignant crée sans
  /// pouvoir vérifier leur absence du reste du club.
  Future<void> confirmUnverified({required bool confirmed}) => _decide(
    _decisions(
      unverified: confirmed ? state.plan?.report.unverifiableStudents ?? 0 : 0,
    ),
  );

  static const List<ClubImportStep> _order = [
    ClubImportStep.report,
    ClubImportStep.groups,
    ClubImportStep.loose,
    ClubImportStep.confirmations,
    ClubImportStep.recap,
  ];

  bool _needed(ClubImportStep step) => switch (step) {
    ClubImportStep.groups => state.groupsNeeded,
    // Les séances et élèves sans groupe ne sont listés qu'une fois les groupes
    // décidés : l'étape se juge sur le plan courant.
    ClubImportStep.loose =>
      (state.plan?.report.undecidedSessions.isNotEmpty ?? false) ||
          (state.plan?.report.undecidedStudents.isNotEmpty ?? false) ||
          state.decisions.plannedSessions.isNotEmpty ||
          state.decisions.students.isNotEmpty,
    ClubImportStep.confirmations =>
      (state.plan?.report.restoredStudents ?? 0) > 0 ||
          (state.plan?.report.unverifiableStudents ?? 0) > 0,
    _ => true,
  };

  /// Passe à l'étape suivante **à décider** (jamais si le plan l'interdit).
  void next() {
    if (state.busy || !state.canContinue) return;
    final index = _order.indexOf(state.step);
    if (index < 0) return;
    for (final step in _order.skip(index + 1)) {
      if (_needed(step)) {
        emit(state.copyWith(step: step));
        return;
      }
    }
  }

  /// Revient à l'étape précédente ; depuis le rapport, au choix du fichier.
  void back() {
    if (state.busy) return;
    final index = _order.indexOf(state.step);
    if (index < 0) return;
    for (final step in _order.take(index).toList().reversed) {
      if (_needed(step)) {
        emit(state.copyWith(step: step));
        return;
      }
    }
    restart();
  }

  /// Repart du choix du fichier (autre fichier : tout est recalculé).
  void restart() {
    if (state.busy) return;
    _backToFile();
  }

  void _backToFile() {
    _content = null;
    emit(
      ClubImportState(
        role: state.role,
        canCreateGroups: state.canCreateGroups,
        online: state.online,
        targets: state.targets,
      ),
    );
  }

  /// Écrit le plan. Reprend au lot suivant le marqueur du club.
  Future<void> start() async {
    if (state.busy || state.plan?.isRunnable != true) return;
    await _execute();
  }

  /// Reprend après une pause, une coupure ou un arrêt.
  Future<void> resume() async {
    if (state.busy) return;
    await _execute();
  }

  /// Demande l'arrêt : l'écriture s'arrête **entre deux lots**.
  void cancel() {
    if (state.run != ClubImportRun.running) return;
    _stopRequested = true;
    emit(state.copyWith(run: ClubImportRun.cancelling));
  }

  Future<void> _execute() async {
    final role = _scope.role;
    if (role == null) return;
    // Défense en profondeur : `_freshPlan` refait le même contrôle.
    if (_content == null) {
      // Le contenu a été réinitialisé (par exemple une reprise après
      // `restart`) : retour au choix du fichier, jamais « en cours » sans fin.
      _backToFile();
      return;
    }
    _stopRequested = false;
    emit(
      state.copyWith(
        busy: true,
        step: ClubImportStep.running,
        run: ClubImportRun.running,
        failure: null,
        runFailure: null,
      ),
    );
    // Le plan est recalculé : un import commencé devient `resumable` au bon
    // lot, un fichier tout écrit devient `alreadyImported`.
    final plan = await _freshPlan();
    if (plan == null) return;
    if (plan.status == ImportStatus.alreadyImported) {
      emit(
        state.copyWith(
          busy: false,
          plan: plan,
          step: ClubImportStep.finished,
          run: null,
        ),
      );
      return;
    }
    if (!plan.isRunnable) {
      final changed = plan.report.problems.any(
        (p) => p.code == ImportProblemCode.planChanged,
      );
      emit(
        state.copyWith(
          busy: false,
          plan: plan,
          run: changed ? ClubImportRun.planChanged : ClubImportRun.failed,
          runFailure: changed
              ? null
              : const ServiceFailure(ServiceFailureCode.other, 'not runnable'),
        ),
      );
      return;
    }
    emit(state.copyWith(plan: plan, totalLots: plan.lots.length));
    final result = await _runner(
      plan,
      role: role,
      shouldStop: () => _stopRequested || isClosed,
      onProgress: (done, total) {
        if (!isClosed) emit(state.copyWith(doneLots: done, totalLots: total));
      },
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            busy: false,
            doneLots: value.doneLots,
            totalLots: value.totalLots,
            step: value.status == ImportRunStatus.completed
                ? ClubImportStep.finished
                : ClubImportStep.running,
            run: switch (value.status) {
              ImportRunStatus.completed => null,
              ImportRunStatus.paused => ClubImportRun.paused,
              ImportRunStatus.interrupted => ClubImportRun.interrupted,
              ImportRunStatus.failed => ClubImportRun.failed,
              ImportRunStatus.cancelled => ClubImportRun.cancelled,
              ImportRunStatus.planChanged => ClubImportRun.planChanged,
            },
            runFailure: value.failure,
          ),
        );
      case Err(:final failure):
        final offline =
            failure is ServiceFailure &&
            failure.code == ServiceFailureCode.unavailable;
        emit(
          state.copyWith(
            busy: false,
            run: offline ? ClubImportRun.interrupted : ClubImportRun.failed,
            runFailure: failure,
          ),
        );
    }
  }

  Future<ClubImportPlan?> _freshPlan() async {
    final content = _content;
    if (content == null) {
      _backToFile();
      return null;
    }
    switch (await _prepare(
      content,
      decisions: state.decisions,
      limits: limits,
    )) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        final offline =
            failure is ServiceFailure &&
            failure.code == ServiceFailureCode.unavailable;
        emit(
          state.copyWith(
            busy: false,
            run: offline ? ClubImportRun.interrupted : ClubImportRun.failed,
            runFailure: failure,
          ),
        );
        return null;
    }
  }

  @override
  Future<void> close() async {
    await _network?.cancel();
    await super.close();
  }
}

/// Ce que le plan courant permet à l'étape affichée.
extension ClubImportGate on ClubImportState {
  /// Les listes de choix de l'étape, dérivées du domaine.
  ImportChoices get choices {
    final plan = this.plan;
    if (plan == null) return ImportChoices.empty;
    return ImportChoices.of(plan: plan, decisions: decisions, targets: targets);
  }

  /// Le bouton « Continuer » est actif : le plan n'est ni bloqué, ni déjà
  /// importé, et l'étape n'attend plus de choix ni de confirmation.
  bool get canContinue {
    final plan = this.plan;
    if (plan == null) return false;
    final report = plan.report;
    return switch (step) {
      ClubImportStep.report =>
        (plan.status != ImportStatus.blocked || plan.awaitsSameChoices) &&
            plan.status != ImportStatus.alreadyImported,
      ClubImportStep.groups =>
        plan.status != ImportStatus.blocked && report.undecidedGroups.isEmpty,
      ClubImportStep.loose =>
        plan.status != ImportStatus.blocked &&
            report.undecidedSessions.isEmpty &&
            report.undecidedStudents.isEmpty,
      ClubImportStep.confirmations =>
        plan.status != ImportStatus.blocked &&
            plan.status != ImportStatus.needsConfirmation,
      _ => false,
    };
  }
}
