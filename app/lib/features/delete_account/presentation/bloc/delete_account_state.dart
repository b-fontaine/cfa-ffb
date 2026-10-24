import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'delete_account_state.freezed.dart';

/// L'écran « Supprimer mon compte ».
@freezed
sealed class DeleteAccountState with _$DeleteAccountState {
  /// Rien n'est demandé.
  const factory DeleteAccountState.idle() = DeleteAccountIdle;

  /// La suppression est en cours, à l'étape [step].
  const factory DeleteAccountState.working(AccountDeletionStep step) =
      DeleteAccountWorking;

  /// Refusée ou arrêtée : [result] dit pourquoi et ce qui était déjà fait.
  /// Le même bouton la relance.
  const factory DeleteAccountState.stopped(AccountDeletionResult result) =
      DeleteAccountStopped;

  /// Le compte est supprimé (la session se ferme, l'écran de connexion suit).
  const factory DeleteAccountState.deleted() = DeleteAccountDone;
}
