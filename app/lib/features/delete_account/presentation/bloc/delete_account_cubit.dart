import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/features/delete_account/presentation/bloc/delete_account_state.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La suppression du compte connecté, telle que la session l'offre
/// (`AuthCubit.deleteAccount`, couche `app`) : la feature n'en connaît que
/// la forme.
typedef AccountDeleter = Future<AccountDeletionResult> Function(
  String password, {
  void Function(AccountDeletionStep step)? onProgress,
});

/// L'écran « Supprimer mon compte » (FB8 partie B, B2) : lance la
/// suppression, montre chaque étape, puis l'issue. Une demande en cours n'est
/// jamais doublée ; après un arrêt, le même bouton relance (la suppression
/// est reprenable).
class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  DeleteAccountCubit(this._delete) : super(const DeleteAccountState.idle());

  final AccountDeleter _delete;

  Future<void> submit(String password) async {
    if (state is DeleteAccountWorking) return;
    emit(
      const DeleteAccountState.working(AccountDeletionStep.checkingIdentity()),
    );
    AccountDeletionResult result;
    try {
      result = await _delete(
        password,
        onProgress: (step) {
          if (!isClosed) emit(DeleteAccountState.working(step));
        },
      );
    } on Failure {
      // Un échec qui n'est pas devenu une issue : l'écran ne reste jamais
      // occupé. L'avancement est inconnu : le message dit qu'une partie a pu
      // être supprimée (jamais « rien »), et rejouer est sans danger.
      result = const AccountDeletionResult.failed(
        AccountDeletionError.unavailable,
        progress: AccountDeletionProgress.clubDataPartlyRemoved,
      );
    }
    // Supprimé : la session se ferme et le routeur quitte l'écran, qui peut
    // déjà être fermé.
    if (isClosed) return;
    emit(
      result is AccountDeleted
          ? const DeleteAccountState.deleted()
          : DeleteAccountState.stopped(result),
    );
  }
}
