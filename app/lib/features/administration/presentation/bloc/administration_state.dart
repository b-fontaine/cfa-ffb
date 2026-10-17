import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'administration_state.freezed.dart';

/// Où en est le chargement de « Administration ».
enum AdministrationStatus { loading, ready, failed }

/// Un club et les invitations de directeur envoyées depuis cet appareil.
@freezed
abstract class AdministeredClub with _$AdministeredClub {
  const factory AdministeredClub({
    required Club club,
    @Default(<IssuedInvitationStatus>[])
    List<IssuedInvitationStatus> invitations,
  }) = _AdministeredClub;
}

@freezed
abstract class AdministrationState with _$AdministrationState {
  const factory AdministrationState({
    @Default(AdministrationStatus.loading) AdministrationStatus status,
    @Default(<AdministeredClub>[]) List<AdministeredClub> clubs,

    /// Dernier échec (chargement ou action).
    Failure? failure,

    /// L'invitation de directeur qui vient d'être créée (son code est à
    /// remettre).
    Invitation? issued,
  }) = _AdministrationState;
}
