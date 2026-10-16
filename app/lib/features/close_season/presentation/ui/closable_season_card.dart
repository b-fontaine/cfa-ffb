import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Carte discrète de « Aujourd'hui » : la saison est terminée et n'est pas
/// close (U11-15). Elle disparaît une fois la saison close.
class ClosableSeasonCard extends StatelessWidget {
  const ClosableSeasonCard({
    required this.season,
    required this.onClose,
    super.key,
  });

  final Season season;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.homeCloseSeasonTitle(season.label),
      emphasis: SectionEmphasis.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeCloseSeasonBody),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onClose,
            child: Text(l10n.homeCloseSeasonAction),
          ),
        ],
      ),
    );
  }
}
