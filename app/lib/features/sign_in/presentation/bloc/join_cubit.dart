import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_failure.dart';
import 'package:billard_cfa/features/sign_in/domain/accept_invitation.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_state.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// « Rejoindre un club » : crée le `member` et consomme l'invitation. Les
/// échecs attendus (code mal formé, introuvable, expiré, utilisé, refusé, nom
/// invalide, service injoignable) deviennent un [JoinFailureCode] localisé par
/// l'interface ; rien n'est jamais affiché en code technique.
@injectable
class JoinCubit extends Cubit<JoinState> {
  JoinCubit(this._accept) : super(const JoinState());

  final AcceptInvitation _accept;

  Future<void> submit({required String code, required String name}) async {
    if (state.status == JoinStatus.submitting) return;
    emit(const JoinState(status: JoinStatus.submitting));
    try {
      await _accept(code: code, displayName: name);
      if (isClosed) return;
      emit(const JoinState(status: JoinStatus.done));
    } on AuthFailure catch (failure) {
      _fail(
        failure.code == AuthFailureCode.invalidInvitationCode
            ? JoinFailureCode.invalidCode
            : JoinFailureCode.unavailable,
      );
    } on InvitationFailure catch (failure) {
      _fail(switch (failure.code) {
        InvitationFailureCode.notFound => JoinFailureCode.notFound,
        InvitationFailureCode.expired => JoinFailureCode.expired,
        InvitationFailureCode.used => JoinFailureCode.used,
        InvitationFailureCode.refused => JoinFailureCode.refused,
      });
    } on InvariantViolation catch (failure) {
      _fail(
        failure.code == InvariantCode.nameRequired ||
                failure.code == InvariantCode.nameTooLong
            ? JoinFailureCode.name
            : JoinFailureCode.refused,
      );
    } on ServiceFailure catch (failure) {
      _fail(
        failure.code == ServiceFailureCode.denied
            ? JoinFailureCode.refused
            : JoinFailureCode.unavailable,
      );
    }
  }

  void _fail(JoinFailureCode code) {
    if (isClosed) return;
    emit(JoinState(status: JoinStatus.failed, failure: code));
  }
}
