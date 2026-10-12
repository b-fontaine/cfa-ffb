import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';

/// Correspondance entre le public du domaine et le design system.
extension AudienceUi on Audience {
  /// Variante du badge de public.
  AudienceKind get kind => switch (this) {
    Audience.children => AudienceKind.children,
    Audience.adults => AudienceKind.adults,
  };

  String label(AppLocalizations l10n) => switch (this) {
    Audience.children => l10n.audienceChildren,
    Audience.adults => l10n.audienceAdults,
  };

  /// Nom du groupe créé automatiquement pour ce public.
  String groupName(AppLocalizations l10n) => switch (this) {
    Audience.children => l10n.groupNameChildren,
    Audience.adults => l10n.groupNameAdults,
  };
}
