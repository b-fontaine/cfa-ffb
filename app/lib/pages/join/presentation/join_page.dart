import 'package:billard_cfa/features/sign_in/presentation/bloc/join_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/join_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// « Rejoindre un club » avec un code d'invitation (cubit fourni par
/// l'appelant). [onJoined] est appelé une fois le `member` créé : l'appelant
/// relit la session et ouvre le club. [onBack] ramène d'où l'on vient ; absent,
/// il n'y a pas de retour (la page est alors la seule sortie : se déconnecter
/// reste possible depuis l'écran « Aucun club »).
class JoinPage extends StatelessWidget {
  const JoinPage({
    required this.onJoined,
    this.initialCode,
    this.onBack,
    this.onSignOut,
    super.key,
  });

  final VoidCallback onJoined;
  final String? initialCode;
  final VoidCallback? onBack;

  /// « Se déconnecter » : la sortie d'un compte sans club (la page est alors
  /// proposée d'office quand un code a été gardé à l'inscription).
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<JoinCubit>();
    return BlocListener<JoinCubit, JoinState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == JoinStatus.done,
      listener: (context, state) => onJoined(),
      child: ScrollPage(
        title: l10n.joinTitle,
        onBack: onBack,
        backLabel: onBack == null ? null : l10n.commonBack,
        maxWidth: 480,
        children: [
          BlocBuilder<JoinCubit, JoinState>(
            builder: (context, state) => JoinForm(
              state: state,
              initialCode: initialCode,
              onSubmit: (code, name) => cubit.submit(code: code, name: name),
            ),
          ),
          if (onSignOut != null)
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: Text(l10n.accountSignOut),
            ),
        ],
      ),
    );
  }
}
