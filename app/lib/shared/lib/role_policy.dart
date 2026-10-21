import 'package:billard_cfa/shared/lib/active_club_scope.dart';

/// Ce qu'un rôle peut faire dans l'application (ADR 0024, matrice des droits).
///
/// Table unique : les routes, les menus et les actions la lisent ; les règles
/// Firestore en sont le garde de fond (`firestore.rules`), l'interface ne fait
/// que ne pas proposer ce que le serveur refuserait.
enum Capability {
  /// Mener les séances, suivre les élèves, saisir les résultats.
  animate,

  /// Modifier les réglages du club.
  manageSettings,

  /// Clore une saison.
  closeSeason,

  /// Ouvrir « Mon club ».
  openClub,

  /// Retirer un membre, changer ses groupes, renommer le club.
  manageClub,

  /// Inviter un enseignant.
  inviteTeachers,

  /// Inviter un élève ou un parent.
  inviteFamilies,

  /// Voir la fiche en parcours de ses enfants (ou la sienne).
  viewChildren,

  /// Ouvrir « Administration » : clubs, directeurs, codes de directeur.
  administer,

  /// Importer une sauvegarde de l'ancienne version dans le club (FB7) : le
  /// directeur et l'administrateur partout, l'enseignant dans ses groupes.
  importBackup,
}

/// Les capacités de chaque rôle.
extension RolePolicy on Role {
  Set<Capability> get capabilities => switch (this) {
    Role.student || Role.guardian => const {Capability.viewChildren},
    Role.teacher => const {
      Capability.animate,
      Capability.openClub,
      Capability.inviteFamilies,
      Capability.importBackup,
    },
    Role.director => const {
      Capability.animate,
      Capability.manageSettings,
      Capability.closeSeason,
      Capability.openClub,
      Capability.manageClub,
      Capability.inviteTeachers,
      Capability.inviteFamilies,
      Capability.importBackup,
    },
    Role.admin => const {
      Capability.animate,
      Capability.manageSettings,
      Capability.closeSeason,
      Capability.openClub,
      Capability.manageClub,
      Capability.inviteTeachers,
      Capability.inviteFamilies,
      Capability.administer,
      Capability.importBackup,
    },
  };

  bool can(Capability capability) => capabilities.contains(capability);

  /// Vrai pour les rôles qui mènent les séances (enseignant, directeur,
  /// administrateur) ; faux pour un élève ou un parent.
  bool get animates => can(Capability.animate);

  /// Les rôles qu'un compte de ce rôle peut inviter (ADR 0024, décision 6) :
  /// l'enseignant ses élèves et parents, le directeur son club (jamais un
  /// directeur), l'administrateur un directeur (et partout, le reste).
  List<Role> get invitableRoles => [
    if (can(Capability.inviteTeachers)) Role.teacher,
    if (can(Capability.inviteFamilies)) ...[Role.student, Role.guardian],
  ];
}
