import 'dart:async';

import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/features/delete_account/presentation/bloc/delete_account_cubit.dart';
import 'package:billard_cfa/features/delete_account/presentation/bloc/delete_account_state.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une suppression scriptée : elle rapporte [steps] puis rend [result].
class _Deleter {
  _Deleter(this.result, {this.steps = const []});

  final AccountDeletionResult result;
  final List<AccountDeletionStep> steps;
  final List<String> passwords = [];
  Completer<void>? gate;

  Future<AccountDeletionResult> call(
    String password, {
    void Function(AccountDeletionStep step)? onProgress,
  }) async {
    passwords.add(password);
    steps.forEach(onProgress ?? (_) {});
    await gate?.future;
    return result;
  }
}

const _leaving = AccountDeletionStep.leavingClub(
  clubName: 'Club Nice',
  index: 1,
  count: 1,
);

void main() {
  test('starts idle', () {
    final cubit = DeleteAccountCubit(
      _Deleter(const AccountDeletionResult.deleted()).call,
    );
    addTearDown(cubit.close);

    expect(cubit.state, const DeleteAccountState.idle());
  });

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'shows each step, then the deletion',
    build: () => DeleteAccountCubit(
      _Deleter(
        const AccountDeletionResult.deleted(),
        steps: const [
          AccountDeletionStep.checkingIdentity(),
          _leaving,
          AccountDeletionStep.removingAccount(),
        ],
      ).call,
    ),
    act: (cubit) => cubit.submit('pw'),
    expect: () => const [
      DeleteAccountState.working(AccountDeletionStep.checkingIdentity()),
      DeleteAccountState.working(_leaving),
      DeleteAccountState.working(AccountDeletionStep.removingAccount()),
      DeleteAccountState.deleted(),
    ],
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'a refusal or a failure stops with its result, and can be retried',
    build: () => DeleteAccountCubit(
      _Deleter(
        const AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
      ).call,
    ),
    act: (cubit) async {
      await cubit.submit('pw');
      await cubit.submit('pw');
    },
    expect: () => const [
      DeleteAccountState.working(AccountDeletionStep.checkingIdentity()),
      DeleteAccountState.stopped(
        AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
      ),
      DeleteAccountState.working(AccountDeletionStep.checkingIdentity()),
      DeleteAccountState.stopped(
        AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
      ),
    ],
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'a failure raised instead of an outcome stops, never claiming that '
    'nothing was deleted: the button comes back, the screen never stays busy',
    build: () => DeleteAccountCubit(
      (password, {onProgress}) async =>
          throw const ServiceFailure(ServiceFailureCode.other, 'stockage'),
    ),
    act: (cubit) => cubit.submit('pw'),
    expect: () => const [
      DeleteAccountState.working(AccountDeletionStep.checkingIdentity()),
      DeleteAccountState.stopped(
        AccountDeletionResult.failed(
          AccountDeletionError.unavailable,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
      ),
    ],
  );

  test('a second submission while working is ignored', () async {
    final deleter = _Deleter(const AccountDeletionResult.deleted())
      ..gate = Completer<void>();
    final cubit = DeleteAccountCubit(deleter.call);
    addTearDown(cubit.close);

    final first = cubit.submit('pw');
    await cubit.submit('pw');
    deleter.gate!.complete();
    await first;

    expect(deleter.passwords, ['pw']);
    expect(cubit.state, const DeleteAccountState.deleted());
  });

  test('closed before the end (the session left the page): no emission '
      'after close', () async {
    final deleter = _Deleter(const AccountDeletionResult.deleted())
      ..gate = Completer<void>();
    final cubit = DeleteAccountCubit(deleter.call);

    final pending = cubit.submit('pw');
    await cubit.close();
    deleter.gate!.complete();

    await expectLater(pending, completes);
  });
}
