import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clé du texte qui montre le code (retrouvé par les scénarios BDD).
const invitationCodeKey = ValueKey<String>('invitation-code');

/// Le code d'une invitation tout juste créée : lisible par groupes de quatre
/// caractères, avec sa date limite, et deux actions de copie de 48 dp : le
/// code, et le lien web quand [linkFor] est fourni (web).
///
/// Le code est annoncé comme une suite de caractères (jamais un mot) ; la copie
/// confirme par un message bref.
class InvitationCodeCard extends StatelessWidget {
  const InvitationCodeCard({
    required this.code,
    required this.validUntil,
    this.linkFor,
    super.key,
  });

  final InvitationCode code;
  final DateTime validUntil;

  /// Construit le lien web de l'invitation (la route est celle du routeur de
  /// l'application, qui fournit cette fonction) ; `null` hors du web : seul le
  /// code se copie.
  final String Function(InvitationCode code)? linkFor;

  Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).inviteCopied;
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final linkFor = this.linkFor;
    return SectionCard(
      title: l10n.inviteResultTitle,
      emphasis: SectionEmphasis.high,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: code.value.split('').join(' '),
            excludeSemantics: true,
            child: SelectableText(
              code.readable,
              key: invitationCodeKey,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.inviteResultHelp),
          Text(l10n.inviteValidUntil(validUntil, validUntil)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _copy(context, code.value),
                icon: const Icon(Icons.copy),
                label: Text(l10n.inviteCopyCode),
              ),
              if (linkFor != null)
                OutlinedButton.icon(
                  onPressed: () => _copy(context, linkFor(code)),
                  icon: const Icon(Icons.link),
                  label: Text(l10n.inviteCopyLink),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
