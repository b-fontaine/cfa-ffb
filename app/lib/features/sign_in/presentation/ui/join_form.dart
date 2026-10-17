import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/auth_fields.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le message localisé d'un échec de « Rejoindre un club ».
String joinFailureMessage(AppLocalizations l10n, JoinFailureCode code) =>
    switch (code) {
      JoinFailureCode.invalidCode => l10n.authErrorInvalidCode(
        minInvitationCodeLength,
      ),
      JoinFailureCode.notFound => l10n.joinErrorNotFound,
      JoinFailureCode.expired => l10n.joinErrorExpired,
      JoinFailureCode.used => l10n.joinErrorUsed,
      JoinFailureCode.refused => l10n.joinErrorRefused,
      JoinFailureCode.name => l10n.joinErrorName(maxDisplayNameLength),
      JoinFailureCode.unavailable => l10n.failServiceUnavailable,
    };

/// Le formulaire « Rejoindre un club » : le code (prérempli quand il vient d'un
/// lien ou de l'inscription), le nom que verra l'équipe, la notice
/// d'information (projet à valider) et l'échec annoncé en région vive.
class JoinForm extends StatefulWidget {
  const JoinForm({
    required this.state,
    required this.onSubmit,
    this.initialCode,
    super.key,
  });

  final JoinState state;
  final void Function(String code, String name) onSubmit;
  final String? initialCode;

  @override
  State<JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<JoinForm> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  final _name = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _busy => widget.state.status == JoinStatus.submitting;

  void _submit() {
    if (!_busy) widget.onSubmit(_code.text, _name.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = widget.state.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.joinIntro),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          decoration: authDecoration(l10n.registerCodeLabel),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _name,
          maxLength: maxDisplayNameLength,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: authDecoration(
            l10n.joinNameLabel,
            hint: l10n.joinNameHint(maxDisplayNameLength),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.joinNotice, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        if (widget.state.status == JoinStatus.failed && failure != null)
          Semantics(
            liveRegion: true,
            child: AppAlert(
              level: AlertLevel.persistent,
              message: joinFailureMessage(l10n, failure),
            ),
          )
        else if (_busy)
          Semantics(liveRegion: true, child: Text(l10n.authSubmitting)),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.joinSubmit),
        ),
      ],
    );
  }
}
