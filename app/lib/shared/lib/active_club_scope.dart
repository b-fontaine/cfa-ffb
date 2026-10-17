import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Rôle d'un compte dans un club (ADR 0024, décision 14 et 16).
///
/// Un compte a un seul rôle par club. `admin` est l'administrateur de
/// l'application (documents `admins/{uid}` créés en console) : il n'a pas de
/// `member` mais peut agir dans un club choisi.
enum Role {
  student,
  guardian,
  teacher,
  director,
  admin;

  /// Lecture tolérante d'une valeur stockée ; `null` si elle est inconnue.
  static Role? tryParse(String? raw) {
    for (final role in values) {
      if (role.name == raw) return role;
    }
    return null;
  }
}

/// Le club actif et le rôle du compte dans ce club (port minuscule, sans
/// dépendance au SDK).
///
/// Les dépôts sont sans état et lisent la portée à chaque appel
/// (ADR 0024, décision 22) ; l'interface se reconstruit au changement de club
/// (`KeyedSubtree`). `null` : aucun club actif.
abstract interface class ActiveClubScope {
  ClubId? get clubId;

  Role? get role;
}
