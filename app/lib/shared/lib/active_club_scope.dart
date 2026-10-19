import 'dart:async';

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

  /// Les groupes du `member` dans le club actif (enseignant : les siens ;
  /// élève ou parent : ceux de sa fiche) ; vide pour un directeur ou un
  /// administrateur, qui voient tout le club.
  List<GroupId> get groupIds;

  /// Les fiches liées au `member` (élève : la sienne ; parent : ses enfants).
  List<StudentId> get studentIds;

  /// Un signal (synchrone, diffusion) à **chaque** écriture de la portée
  /// (club, rôle, groupes, fiches), qu'elle change ou non la valeur : les
  /// flux épinglés (`ClubStore`) comparent alors leur portée d'ouverture à la
  /// courante et se ferment sans attendre un événement du serveur.
  Stream<void> get changes;
}

/// La clé de la portée : club, rôle, groupes et fiches. Les groupes et les
/// fiches y sont **triés** : le même ensemble relu dans un autre ordre est la
/// même portée (rien ne se ferme ni ne se reconstruit pour si peu).
String scopeKeyOf({
  ClubId? club,
  Role? role,
  Iterable<GroupId> groups = const [],
  Iterable<StudentId> students = const [],
}) =>
    '${club?.value}|${role?.name}|'
    '${([for (final id in groups) id.value]..sort()).join(',')}|'
    '${([for (final id in students) id.value]..sort()).join(',')}';
