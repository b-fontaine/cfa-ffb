import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';

/// Libellé localisé d'un rôle de club.
extension RoleLabel on Role {
  String label(AppLocalizations l10n) => switch (this) {
    Role.student => l10n.roleStudent,
    Role.guardian => l10n.roleGuardian,
    Role.teacher => l10n.roleTeacher,
    Role.director => l10n.roleDirector,
    Role.admin => l10n.roleAdmin,
  };
}
