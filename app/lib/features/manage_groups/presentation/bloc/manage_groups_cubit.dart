import 'package:billard_cfa/features/manage_groups/domain/create_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/delete_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/rename_group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'manage_groups_cubit.freezed.dart';

enum ManageGroupsStatus { idle, working, done, refused }

enum ManageGroupsAction { create, rename, delete }

/// Dernière demande sur les groupes : son [action], son [name] (le nom donné
/// ou celui du groupe supprimé) et son issue ([failure] si elle est refusée).
@freezed
abstract class ManageGroupsState with _$ManageGroupsState {
  const factory ManageGroupsState({
    @Default(ManageGroupsStatus.idle) ManageGroupsStatus status,
    ManageGroupsAction? action,
    String? name,
    Failure? failure,
  }) = _ManageGroupsState;
}

/// Créer, renommer et supprimer un groupe depuis la liste des élèves
/// (ADR 0019). Les confirmations sont demandées par l'écran.
@injectable
class ManageGroupsCubit extends Cubit<ManageGroupsState> {
  ManageGroupsCubit(this._create, this._rename, this._delete, this._clock)
    : super(const ManageGroupsState());

  final CreateGroup _create;
  final RenameGroup _rename;
  final DeleteGroup _delete;
  final Clock _clock;

  Future<void> create({
    required SeasonId seasonId,
    required String name,
    required Audience audience,
  }) async {
    emit(_working(ManageGroupsAction.create, name));
    final result = await _create(
      seasonId: seasonId,
      name: name,
      audience: audience,
    );
    _conclude(ManageGroupsAction.create, name, result);
  }

  Future<void> rename({required GroupId groupId, required String name}) async {
    emit(_working(ManageGroupsAction.rename, name));
    _conclude(
      ManageGroupsAction.rename,
      name,
      await _rename(groupId: groupId, name: name),
    );
  }

  /// [name] ne sert qu'au message de retour (le groupe supprimé).
  Future<void> delete({required GroupId groupId, required String name}) async {
    emit(_working(ManageGroupsAction.delete, name));
    _conclude(
      ManageGroupsAction.delete,
      name,
      await _delete(groupId: groupId, today: _clock.today()),
    );
  }

  ManageGroupsState _working(ManageGroupsAction action, String name) =>
      ManageGroupsState(
        status: ManageGroupsStatus.working,
        action: action,
        name: name,
      );

  void _conclude(
    ManageGroupsAction action,
    String name,
    Result<Object?> result,
  ) => emit(switch (result) {
    Ok() => ManageGroupsState(
      status: ManageGroupsStatus.done,
      action: action,
      name: name,
    ),
    Err(:final failure) => ManageGroupsState(
      status: ManageGroupsStatus.refused,
      action: action,
      name: name,
      failure: failure,
    ),
  });
}
