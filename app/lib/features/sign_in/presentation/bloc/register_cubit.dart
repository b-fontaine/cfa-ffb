import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/domain/register_with_invitation.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Écran d'inscription par code d'invitation (inscription fermée).
@injectable
class RegisterCubit extends Cubit<AuthFormState> {
  RegisterCubit(this._register) : super(const AuthFormState());

  final RegisterWithInvitation _register;

  Future<void> submit({
    required String code,
    required String email,
    required String password,
  }) async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(const AuthFormState(status: AuthFormStatus.submitting));
    try {
      final registration = await _register(
        code: code,
        email: email,
        password: password,
      );
      if (isClosed) return;
      emit(
        AuthFormState(
          status: AuthFormStatus.done,
          verificationSent: registration.verificationSent,
        ),
      );
    } on AuthFailure catch (failure) {
      _fail(failure.code);
    } on Object {
      _fail(AuthFailureCode.unavailable);
    }
  }

  void _fail(AuthFailureCode code) {
    if (isClosed) return;
    emit(AuthFormState(status: AuthFormStatus.failed, failure: code));
  }
}
