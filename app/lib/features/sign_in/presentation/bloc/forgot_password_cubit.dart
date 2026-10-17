import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/domain/request_password_reset.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Écran « Mot de passe oublié » : la même confirmation que l'adresse soit
/// connue ou non (anti-énumération).
@injectable
class ForgotPasswordCubit extends Cubit<AuthFormState> {
  ForgotPasswordCubit(this._reset) : super(const AuthFormState());

  final RequestPasswordReset _reset;

  Future<void> submit({required String email}) async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(const AuthFormState(status: AuthFormStatus.submitting));
    try {
      await _reset(email: email);
      if (!isClosed) emit(const AuthFormState(status: AuthFormStatus.done));
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
