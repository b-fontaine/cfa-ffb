import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/features/administration/domain/create_club.dart';
import 'package:billard_cfa/features/administration/domain/invite_director.dart';
import 'package:billard_cfa/features/administration/domain/list_clubs.dart';
import 'package:billard_cfa/features/administration/domain/list_director_invitations.dart';
import 'package:billard_cfa/features/administration/domain/revoke_director_invitation.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_state.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// « Administration » : les clubs, leur création, et les invitations de
/// directeur (créer, copier, révoquer). Un échec d'action garde la liste et
/// s'affiche ; l'action suivante l'efface.
@injectable
class AdministrationCubit extends Cubit<AdministrationState> {
  AdministrationCubit(
    this._listClubs,
    this._createClub,
    this._inviteDirector,
    this._listInvitations,
    this._revoke,
  ) : super(const AdministrationState());

  final ListClubs _listClubs;
  final CreateClub _createClub;
  final InviteDirector _inviteDirector;
  final ListDirectorInvitations _listInvitations;
  final RevokeDirectorInvitation _revoke;

  Future<void> load() async {
    final result = await _listClubs();
    final List<Club> clubs;
    switch (result) {
      case Err(:final failure):
        if (isClosed) return;
        emit(
          state.copyWith(status: AdministrationStatus.failed, failure: failure),
        );
        return;
      case Ok(:final value):
        clubs = value;
    }
    final administered = <AdministeredClub>[];
    for (final club in clubs) {
      final invitations = await _listInvitations(club.id);
      administered.add(
        AdministeredClub(
          club: club,
          invitations: switch (invitations) {
            Ok(:final value) => value,
            Err() => const [],
          },
        ),
      );
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: AdministrationStatus.ready,
        clubs: administered,
        failure: null,
      ),
    );
  }

  /// Crée un club ; `true` si le serveur l'a accepté.
  Future<bool> createClub(String name) async {
    final result = await _createClub(name);
    if (isClosed) return false;
    switch (result) {
      case Ok():
        await load();
        return true;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return false;
    }
  }

  Future<void> inviteDirector(ClubId club) async {
    final result = await _inviteDirector(club);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(issued: value, failure: null));
        await load();
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  /// Referme le code affiché (il reste dans la liste de l'appareil).
  void dismissIssued() => emit(state.copyWith(issued: null));

  Future<void> revoke(ClubId club, InvitationCode code) async {
    final result = await _revoke(club, code);
    if (isClosed) return;
    switch (result) {
      case Ok():
        if (state.issued?.code == code) emit(state.copyWith(issued: null));
        await load();
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }
}
