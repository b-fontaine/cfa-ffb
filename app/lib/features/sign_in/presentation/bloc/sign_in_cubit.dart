import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/domain/resend_verification.dart';
import 'package:billard_cfa/features/sign_in/domain/sign_in.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Écran de connexion. Réussir ne change pas l'écran lui-même : `AuthCubit`
/// voit le compte arriver et le routeur quitte la page.
@injectable
class SignInCubit extends Cubit<AuthFormState> {
  SignInCubit(this._signIn, this._resend) : super(const AuthFormState());

  final SignIn _signIn;
  final ResendVerification _resend;

  Future<void> submit({required String email, required String password}) async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(const AuthFormState(status: AuthFormStatus.submitting));
    try {
      await _signIn(email: email, password: password);
      if (!isClosed) emit(const AuthFormState(status: AuthFormStatus.done));
    } on AuthFailure catch (failure) {
      _fail(failure.code);
    } on Object {
      _fail(AuthFailureCode.unavailable);
    }
  }

  /// Renvoie le courriel de vérification (écran « adresse non vérifiée »).
  Future<void> resendVerification({
    required String email,
    required String password,
  }) async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(
      AuthFormState(status: AuthFormStatus.submitting, failure: state.failure),
    );
    try {
      final sent = await _resend(email: email, password: password);
      if (isClosed) return;
      emit(
        sent
            ? const AuthFormState(
                status: AuthFormStatus.failed,
                failure: AuthFailureCode.emailNotVerified,
                verificationSent: true,
              )
            : const AuthFormState(),
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
