import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:flutter/widgets.dart';

/// « Se déconnecter » : vide le cache local des données du club (C4). Si des
/// écritures faites sans réseau n'ont pas encore été envoyées, la déconnexion
/// les perdrait : l'utilisateur doit le confirmer, **sans** qu'on lui montre
/// la moindre donnée de l'élève.
Future<void> requestSignOut(BuildContext context, AuthCubit auth) async {
  final result = await auth.signOut();
  if (result != SignOutResult.unsentWrites || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.signOutUnsentTitle,
    message: l10n.signOutUnsentBody,
    confirmLabel: l10n.signOutUnsentConfirm,
  );
  if (confirmed) await auth.signOut(discardUnsent: true);
}
