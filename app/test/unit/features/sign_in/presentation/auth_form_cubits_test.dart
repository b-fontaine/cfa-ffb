import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/data/key_value_pending_invitations.dart';
import 'package:billard_cfa/features/sign_in/domain/register_with_invitation.dart';
import 'package:billard_cfa/features/sign_in/domain/request_password_reset.dart';
import 'package:billard_cfa/features/sign_in/domain/resend_verification.dart';
import 'package:billard_cfa/features/sign_in/domain/sign_in.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/forgot_password_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/register_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/sign_in_cubit.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

const _submitting = AuthFormState(status: AuthFormStatus.submitting);
const _done = AuthFormState(status: AuthFormStatus.done);

AuthFormState _failed(AuthFailureCode code) =>
    AuthFormState(status: AuthFormStatus.failed, failure: code);

/// Dépôt qui échoue autrement que par un `AuthFailure` (bogue, plateforme).
class _ExplodingAuth extends InMemoryAuthRepository {
  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw StateError('boum');

  @override
  Future<Account> register({required String email, required String password}) =>
      throw StateError('boum');

  @override
  Future<void> sendPasswordReset(String email) => throw StateError('boum');
}

void main() {
  late InMemoryAuthRepository auth;

  setUp(() => auth = InMemoryAuthRepository());

  group('SignInCubit', () {
    SignInCubit build() => SignInCubit(SignIn(auth), ResendVerification(auth));

    blocTest<SignInCubit, AuthFormState>(
      'a verified account signs in',
      setUp: () => auth.seed(email: 'coach@example.org', password: 'pw'),
      build: build,
      act: (c) => c.submit(email: 'coach@example.org', password: 'pw'),
      expect: () => [_submitting, _done],
    );

    blocTest<SignInCubit, AuthFormState>(
      'wrong credentials fail generically',
      build: build,
      act: (c) => c.submit(email: 'coach@example.org', password: 'pw'),
      expect: () => [_submitting, _failed(AuthFailureCode.invalidCredentials)],
    );

    blocTest<SignInCubit, AuthFormState>(
      'a network failure keeps its own code',
      setUp: () => auth.offline = true,
      build: build,
      act: (c) => c.submit(email: 'coach@example.org', password: 'pw'),
      expect: () => [_submitting, _failed(AuthFailureCode.network)],
    );

    blocTest<SignInCubit, AuthFormState>(
      'a second submit while one is running is ignored',
      setUp: () => auth.seed(email: 'coach@example.org', password: 'pw'),
      build: build,
      act: (c) {
        final first = c.submit(email: 'coach@example.org', password: 'pw');
        final second = c.submit(email: 'coach@example.org', password: 'pw');
        return Future.wait([first, second]);
      },
      expect: () => [_submitting, _done],
    );

    blocTest<SignInCubit, AuthFormState>(
      'resending the e-mail keeps the "not verified" message, marks it sent',
      setUp: () => auth.seed(
        email: 'new@example.org',
        password: 'pw',
        emailVerified: false,
      ),
      build: build,
      act: (c) =>
          c.resendVerification(email: 'new@example.org', password: 'pw'),
      expect: () => [
        _submitting,
        const AuthFormState(
          status: AuthFormStatus.failed,
          failure: AuthFailureCode.emailNotVerified,
          verificationSent: true,
        ),
      ],
    );

    blocTest<SignInCubit, AuthFormState>(
      'resending to an address already verified goes back to editing',
      setUp: () => auth.seed(email: 'coach@example.org', password: 'pw'),
      build: build,
      act: (c) =>
          c.resendVerification(email: 'coach@example.org', password: 'pw'),
      expect: () => [_submitting, const AuthFormState()],
    );

    blocTest<SignInCubit, AuthFormState>(
      'resending with a wrong password fails generically',
      setUp: () => auth.seed(
        email: 'new@example.org',
        password: 'pw',
        emailVerified: false,
      ),
      build: build,
      act: (c) =>
          c.resendVerification(email: 'new@example.org', password: 'wrong'),
      expect: () => [_submitting, _failed(AuthFailureCode.invalidCredentials)],
    );

    blocTest<SignInCubit, AuthFormState>(
      'resending while a request runs is ignored',
      setUp: () => auth.seed(
        email: 'new@example.org',
        password: 'pw',
        emailVerified: false,
      ),
      build: build,
      act: (c) {
        final first = c.resendVerification(
          email: 'new@example.org',
          password: 'pw',
        );
        final second = c.resendVerification(
          email: 'new@example.org',
          password: 'pw',
        );
        return Future.wait([first, second]);
      },
      expect: () => [_submitting, isA<AuthFormState>()],
    );
  });

  group('RegisterCubit', () {
    RegisterCubit build() => RegisterCubit(
      RegisterWithInvitation(
        auth,
        KeyValuePendingInvitations(InMemoryKeyValueStore()),
      ),
    );

    blocTest<RegisterCubit, AuthFormState>(
      'creates the account and says the e-mail was sent',
      build: build,
      act: (c) => c.submit(
        code: 'ABCDEFGHJK',
        email: 'new@example.org',
        password: 'long-enough-password',
      ),
      expect: () => [
        _submitting,
        const AuthFormState(
          status: AuthFormStatus.done,
          verificationSent: true,
        ),
      ],
    );

    blocTest<RegisterCubit, AuthFormState>(
      'says when the e-mail could not be sent',
      setUp: () => auth.verificationMailFails = true,
      build: build,
      act: (c) => c.submit(
        code: 'ABCDEFGHJK',
        email: 'new@example.org',
        password: 'long-enough-password',
      ),
      expect: () => [_submitting, _done],
    );

    blocTest<RegisterCubit, AuthFormState>(
      'a short password fails',
      build: build,
      act: (c) =>
          c.submit(code: 'ABCDEFGHJK', email: 'new@example.org', password: 'x'),
      expect: () => [_submitting, _failed(AuthFailureCode.weakPassword)],
    );

    blocTest<RegisterCubit, AuthFormState>(
      'a second submit while one is running is ignored',
      build: build,
      act: (c) {
        final first = c.submit(
          code: 'ABCDEFGHJK',
          email: 'new@example.org',
          password: 'long-enough-password',
        );
        final second = c.submit(
          code: 'ABCDEFGHJK',
          email: 'new@example.org',
          password: 'long-enough-password',
        );
        return Future.wait([first, second]);
      },
      expect: () => [_submitting, isA<AuthFormState>()],
    );
  });

  group('ForgotPasswordCubit', () {
    ForgotPasswordCubit build() =>
        ForgotPasswordCubit(RequestPasswordReset(auth));

    blocTest<ForgotPasswordCubit, AuthFormState>(
      'confirms the same way for a known and an unknown address',
      build: build,
      act: (c) async {
        await c.submit(email: 'nobody@example.org');
        await c.submit(email: 'nobody@example.org');
      },
      expect: () => [_submitting, _done, _submitting, _done],
    );

    blocTest<ForgotPasswordCubit, AuthFormState>(
      'a malformed address fails',
      build: build,
      act: (c) => c.submit(email: 'nope'),
      expect: () => [_submitting, _failed(AuthFailureCode.invalidEmail)],
    );

    blocTest<ForgotPasswordCubit, AuthFormState>(
      'offline fails with the network code',
      setUp: () => auth.offline = true,
      build: build,
      act: (c) => c.submit(email: 'a@b.cd'),
      expect: () => [_submitting, _failed(AuthFailureCode.network)],
    );

    blocTest<ForgotPasswordCubit, AuthFormState>(
      'a second submit while one is running is ignored',
      build: build,
      act: (c) {
        final first = c.submit(email: 'a@b.cd');
        final second = c.submit(email: 'a@b.cd');
        return Future.wait([first, second]);
      },
      expect: () => [_submitting, _done],
    );
  });

  group('an unexpected error is "unavailable", never a stack trace', () {
    final exploding = _ExplodingAuth();

    blocTest<SignInCubit, AuthFormState>(
      'sign-in',
      build: () =>
          SignInCubit(SignIn(exploding), ResendVerification(exploding)),
      act: (c) => c.submit(email: 'a@b.cd', password: 'pw'),
      expect: () => [_submitting, _failed(AuthFailureCode.unavailable)],
    );

    blocTest<SignInCubit, AuthFormState>(
      'resending the verification e-mail',
      build: () =>
          SignInCubit(SignIn(exploding), ResendVerification(exploding)),
      act: (c) => c.resendVerification(email: 'a@b.cd', password: 'pw'),
      expect: () => [_submitting, _failed(AuthFailureCode.unavailable)],
    );

    blocTest<RegisterCubit, AuthFormState>(
      'sign-up',
      build: () => RegisterCubit(
        RegisterWithInvitation(
          exploding,
          KeyValuePendingInvitations(InMemoryKeyValueStore()),
        ),
      ),
      act: (c) => c.submit(
        code: 'ABCDEFGHJK',
        email: 'a@b.cd',
        password: 'long-enough-password',
      ),
      expect: () => [_submitting, _failed(AuthFailureCode.unavailable)],
    );

    blocTest<ForgotPasswordCubit, AuthFormState>(
      'password reset',
      build: () => ForgotPasswordCubit(RequestPasswordReset(exploding)),
      act: (c) => c.submit(email: 'a@b.cd'),
      expect: () => [_submitting, _failed(AuthFailureCode.unavailable)],
    );
  });
}
