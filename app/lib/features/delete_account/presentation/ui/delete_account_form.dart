import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/features/delete_account/presentation/bloc/delete_account_state.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Formulaire « Supprimer mon compte » (FB8 partie B, B2) : ce qui est
/// supprimé et ce qui reste au club, le mot de passe (vérifié avant toute
/// écriture), l'avancement et l'issue. Sans état métier : la page lui donne
/// [state] et reçoit [onSubmit].
///
/// Accessibilité : l'avancement et l'issue sont dans une **région vive**
/// (annoncés à leur apparition) ; une issue n'est jamais portée par la seule
/// couleur ([AppAlert] : icône et libellé) ; le bouton est désactivé pendant
/// la suppression.
class DeleteAccountForm extends StatefulWidget {
  const DeleteAccountForm({
    required this.state,
    required this.onSubmit,
    super.key,
  });

  final DeleteAccountState state;
  final ValueChanged<String> onSubmit;

  @override
  State<DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<DeleteAccountForm> {
  final _password = TextEditingController();
  bool _missing = false;

  bool get _busy => switch (widget.state) {
    DeleteAccountWorking() || DeleteAccountDone() => true,
    DeleteAccountIdle() || DeleteAccountStopped() => false,
  };

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_busy) return;
    final password = _password.text;
    setState(() => _missing = password.isEmpty);
    if (password.isNotEmpty) widget.onSubmit(password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.deleteAccountIntro),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.deleteAccountStays),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _password,
          obscureText: true,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.deleteAccountPassword,
            helperText: l10n.deleteAccountPasswordHint,
            errorText: _missing ? l10n.deleteAccountPasswordRequired : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          liveRegion: true,
          child: _DeletionStatus(state: widget.state),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l10n.deleteAccountConfirm),
        ),
      ],
    );
  }
}

/// L'avancement ou l'issue de la suppression ; rien avant la demande.
class _DeletionStatus extends StatelessWidget {
  const _DeletionStatus({required this.state});

  final DeleteAccountState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      DeleteAccountIdle() => const SizedBox.shrink(),
      DeleteAccountWorking(:final step) => Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(deletionStepLabel(l10n, step))),
        ],
      ),
      DeleteAccountStopped(:final result) => AppAlert(
        level: result is AccountDeletionRefused
            ? AlertLevel.attention
            : AlertLevel.persistent,
        message: deletionResultMessage(l10n, result),
      ),
      DeleteAccountDone() => Text(l10n.deleteAccountDone),
    };
  }
}

/// Le libellé d'une étape de la suppression.
String deletionStepLabel(AppLocalizations l10n, AccountDeletionStep step) =>
    switch (step) {
      CheckingIdentity() => l10n.deleteAccountStepChecking,
      LeavingClub(:final clubName?, :final index, :final count) =>
        l10n.deleteAccountStepLeaving(clubName, index, count),
      LeavingClub(:final index, :final count) =>
        l10n.deleteAccountStepLeavingUnnamed(index, count),
      RemovingAccount() => l10n.deleteAccountStepRemoving,
    };

/// Le message d'une issue : il dit toujours ce qui a été supprimé (rien, une
/// partie, les données du club) et quoi faire.
String deletionResultMessage(
  AppLocalizations l10n,
  AccountDeletionResult result,
) => switch (result) {
  AccountDeleted() => l10n.deleteAccountDone,
  AccountDeletionRefused(:final reason, :final clubName) => switch (reason) {
    AccountDeletionRefusal.unsentWrites => l10n.deleteAccountRefusedUnsent,
    AccountDeletionRefusal.administrator => l10n.deleteAccountAdministrator,
    AccountDeletionRefusal.lastDirector =>
      l10n.deleteAccountRefusedLastDirector(clubName ?? ''),
  },
  AccountDeletionFailed(:final error, :final progress) => switch (error) {
    // Chaque erreur se lit avec l'avancement : un refus d'Auth peut arriver
    // après la purge des clubs (`deleteAccount`), et une vérification
    // expirée sans aucun club n'a rien supprimé.
    AccountDeletionError.wrongPassword => switch (progress) {
      AccountDeletionProgress.nothingDeleted => l10n.deleteAccountWrongPassword,
      AccountDeletionProgress.clubDataPartlyRemoved =>
        l10n.deleteAccountWrongPasswordPartial,
      AccountDeletionProgress.clubDataRemoved =>
        l10n.deleteAccountWrongPasswordClubDataRemoved,
    },
    AccountDeletionError.tooManyRequests => switch (progress) {
      AccountDeletionProgress.nothingDeleted =>
        l10n.deleteAccountTooManyRequests,
      AccountDeletionProgress.clubDataPartlyRemoved =>
        l10n.deleteAccountTooManyRequestsPartial,
      AccountDeletionProgress.clubDataRemoved =>
        l10n.deleteAccountTooManyRequestsClubDataRemoved,
    },
    AccountDeletionError.passwordCheckExpired => switch (progress) {
      AccountDeletionProgress.nothingDeleted =>
        l10n.deleteAccountPasswordExpiredNothing,
      AccountDeletionProgress.clubDataPartlyRemoved =>
        l10n.deleteAccountPasswordExpiredPartial,
      AccountDeletionProgress.clubDataRemoved =>
        l10n.deleteAccountPasswordExpired,
    },
    AccountDeletionError.network => switch (progress) {
      AccountDeletionProgress.nothingDeleted =>
        l10n.deleteAccountNetworkNothing,
      AccountDeletionProgress.clubDataPartlyRemoved =>
        l10n.deleteAccountNetworkPartial,
      AccountDeletionProgress.clubDataRemoved =>
        l10n.deleteAccountNetworkClubDataRemoved,
    },
    AccountDeletionError.unavailable => switch (progress) {
      AccountDeletionProgress.nothingDeleted => l10n.deleteAccountFailedNothing,
      AccountDeletionProgress.clubDataPartlyRemoved =>
        l10n.deleteAccountFailedPartial,
      AccountDeletionProgress.clubDataRemoved =>
        l10n.deleteAccountFailedClubDataRemoved,
    },
  },
};
