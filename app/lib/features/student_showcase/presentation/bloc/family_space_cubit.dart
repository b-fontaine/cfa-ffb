import 'package:billard_cfa/features/student_showcase/domain/check_family_access.dart';
import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/watch_family_space.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/live_reload.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'family_space_cubit.freezed.dart';

/// Où en est l'espace d'un parent ou d'un élève.
///
/// - [loading] : première lecture ;
/// - [ready] : les données (éventuellement [FamilySpaceState.stale]) ;
/// - [failed] : service injoignable ou autre échec, « Réessayer » ;
/// - [denied] : le serveur **refuse** la lecture alors que le lien existe
///   encore (règle, configuration) : réessayer n'y change rien, distinct de
///   [failed] ;
/// - [revoked] : le lien du compte à ses fiches a été retiré (le flux est
///   fermé, plus aucune donnée n'est gardée à l'écran).
enum FamilyStatus { loading, ready, failed, denied, revoked }

@freezed
abstract class FamilySpaceState with _$FamilySpaceState {
  const factory FamilySpaceState({
    @Default(FamilyStatus.loading) FamilyStatus status,
    FamilySpace? space,

    /// L'élève affiché (toujours l'un des élèves de [space]).
    StudentId? selected,

    /// Les dernières données sont affichées faute de pouvoir joindre le
    /// serveur (hors ligne).
    @Default(false) bool stale,
    Failure? failure,
  }) = _FamilySpaceState;
}

/// L'espace d'un parent ou d'un élève, en lecture seule (FB6) : ses élèves
/// liés, un seul affiché à la fois (le choix survit aux relectures), et les
/// prochaines séances de ses groupes.
///
/// **Temps réel** : un seul abonnement (`WatchFamilySpace`), ouvert au premier
/// [load], relâché à la fermeture et dès que l'accès est retiré. Le parcours de
/// chaque élève est lu et gardé **par élève** : basculer de l'un à l'autre ne
/// relit rien et ne mélange jamais deux élèves.
@injectable
class FamilySpaceCubit extends Cubit<FamilySpaceState> {
  FamilySpaceCubit(this._get, this._watch, this._access)
    : super(const FamilySpaceState()) {
    _live = LiveReload(open: _watch.call, reload: _refresh);
  }

  final GetFamilySpace _get;
  final WatchFamilySpace _watch;
  final CheckFamilyAccess _access;
  late final LiveReload _live;

  /// (Re)charge l'espace ; sert aussi de « Réessayer ».
  Future<void> load() async {
    // Accès retiré : rien à relire, rien à rouvrir.
    if (state.status == FamilyStatus.revoked) return;
    if (state.status == FamilyStatus.failed ||
        state.status == FamilyStatus.denied) {
      _live.restart();
    } else {
      _live.start();
    }
    if (state.status != FamilyStatus.loading && state.space == null) {
      emit(const FamilySpaceState());
    }
    await _refresh();
  }

  /// Affiche [id] (sans effet si ce n'est pas l'un des élèves liés).
  void select(StudentId id) {
    final space = state.space;
    if (space == null || !space.children.any((child) => child.id == id)) return;
    emit(state.copyWith(selected: id));
  }

  /// Relit l'espace sans repasser par le chargement.
  Future<void> _refresh() async {
    if (state.status == FamilyStatus.revoked) return;
    try {
      await _read();
    } on Object {
      // Une erreur imprévue ne remonte jamais jusqu'à `load()` ni au flux : un
      // état d'erreur localisé, avec « Réessayer ».
      if (!isClosed) {
        emit(
          const FamilySpaceState(
            status: FamilyStatus.failed,
            failure: ServiceFailure(ServiceFailureCode.other),
          ),
        );
      }
    }
  }

  Future<void> _read() async {
    // Le lien d'abord : les lectures des données peuvent encore être servies
    // par les écoutes ouvertes (le serveur ne renvoie rien pour un document
    // qui n'a pas changé), alors que le lien, lui, est refusé dès qu'il est
    // supprimé. Un lien disparu est donc le seul signal sûr d'un accès retiré.
    final access = await _access();
    if (isClosed) return;
    if (access is! AccessGranted) {
      await _revoke();
      return;
    }
    final result = await _get(linked: access.studentIds);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          FamilySpaceState(
            status: FamilyStatus.ready,
            space: value,
            selected: _kept(value),
          ),
        );
      case Err(:final failure):
        await _fail(failure);
    }
  }

  /// L'élève affiché reste le même tant qu'il est lié ; sinon le premier.
  StudentId? _kept(FamilySpace space) {
    final current = state.selected;
    if (current != null && space.children.any((c) => c.id == current)) {
      return current;
    }
    return space.children.firstOrNull?.id;
  }

  Future<void> _fail(Failure failure) async {
    if (failure is ServiceFailure &&
        failure.code == ServiceFailureCode.denied) {
      final access = await _access();
      if (isClosed) return;
      if (access is! AccessGranted) {
        await _revoke();
      } else {
        emit(FamilySpaceState(status: FamilyStatus.denied, failure: failure));
      }
      return;
    }
    final space = state.space;
    if (failure is ServiceFailure &&
        failure.code == ServiceFailureCode.unavailable &&
        space != null) {
      // Hors ligne : les dernières données restent affichées.
      emit(state.copyWith(stale: true));
      return;
    }
    emit(FamilySpaceState(status: FamilyStatus.failed, failure: failure));
  }

  /// Accès retiré : on se désabonne et on n'affiche plus rien.
  Future<void> _revoke() async {
    await _live.stop();
    if (!isClosed) emit(const FamilySpaceState(status: FamilyStatus.revoked));
  }

  @override
  Future<void> close() async {
    await _live.stop();
    await super.close();
  }
}
