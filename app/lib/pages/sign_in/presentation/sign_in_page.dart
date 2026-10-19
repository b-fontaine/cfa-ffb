import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/sign_in_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/erasure_pending_notice.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/shared_device_note.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/sign_in_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Connexion (bloc fourni par l'appelant). Réussir ne navigue pas ici : la
/// session change et le routeur quitte la page.
class SignInPage extends StatelessWidget {
  const SignInPage({
    required this.onForgotPassword,
    required this.onRegister,
    this.erasurePending = false,
    this.onRetryErasure,
    super.key,
  });

  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  /// L'effacement du cache local de la déconnexion précédente n'a pas abouti :
  /// le message et « Réessayer l'effacement » s'affichent.
  final bool erasurePending;
  final VoidCallback? onRetryErasure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SignInCubit>();
    return ScrollPage(
      title: l10n.signInTitle,
      subtitle: l10n.signInIntro,
      maxWidth: 480,
      children: [
        if (erasurePending && onRetryErasure != null) ...[
          ErasurePendingNotice(onRetry: onRetryErasure!),
          const SizedBox(height: AppSpacing.lg),
        ],
        BlocBuilder<SignInCubit, AuthFormState>(
          builder: (context, state) => SignInForm(
            state: state,
            onSubmit: (email, password) =>
                cubit.submit(email: email, password: password),
            onResendVerification: (email, password) =>
                cubit.resendVerification(email: email, password: password),
            onForgotPassword: onForgotPassword,
            onRegister: onRegister,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SharedDeviceNote(),
      ],
    );
  }
}
