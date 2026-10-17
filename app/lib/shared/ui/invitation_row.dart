import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une invitation émise depuis cet appareil : son code lisible, un sous-titre
/// « rôle · état » et, si [onRevoke] est donné, un bouton « Révoquer » de
/// 48 dp. L'état est écrit en toutes lettres (jamais la couleur seule).
class InvitationRow extends StatelessWidget {
  const InvitationRow({
    required this.code,
    required this.subtitle,
    required this.revokeLabel,
    this.onRevoke,
    super.key,
  });

  final String code;
  final String subtitle;
  final String revokeLabel;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(code),
      subtitle: Text(subtitle),
      trailing: onRevoke == null
          ? null
          : TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
              ),
              onPressed: onRevoke,
              child: Text(revokeLabel),
            ),
    );
  }
}
