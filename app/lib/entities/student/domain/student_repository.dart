import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux élèves (implémenté dans la couche data).
///
/// Contrat commun à toutes les implémentations (suite de contrat unique) :
/// l'ordre de [all] est l'ordre de première sauvegarde, la sauvegarde d'un id
/// existant remplace l'élève sans changer sa position, et la suppression est
/// logique (l'élève disparaît des lectures, une nouvelle sauvegarde le
/// rétablit).
abstract interface class StudentRepository {
  /// **Inscrit** l'élève : la création, faite par le seul parcours
  /// d'inscription (ou la restauration). Dans un club Firestore, c'est la
  /// seule écriture qui peut faire naître une fiche.
  Future<void> create(Student student);

  /// Enregistre l'élève : remplace sa fiche (en local) ou met à jour ses champs
  /// propres (club Firestore, où l'écriture **échoue** sur une fiche absente :
  /// une édition rejouée par un appareil resté hors ligne ne recrée jamais une
  /// fiche effacée, ADR 0025).
  Future<void> save(Student student);

  Future<Student?> byId(StudentId id);

  Future<List<Student>> all();

  /// Supprime logiquement l'élève ; sans effet s'il n'existe pas.
  Future<void> delete(StudentId id);

  /// Efface physiquement l'élève et son historique de public (droit à
  /// l'effacement) : aucune trace ne subsiste, y compris d'une suppression
  /// logique antérieure ; sans effet s'il n'existe pas.
  Future<void> erase(StudentId id);

  /// Suit une fiche (FB5b) : son état courant, puis un état à chaque
  /// changement, de cet appareil ou d'un autre ; `null` quand elle n'existe
  /// pas (ou plus). Ajout **ciblé** : les `Future` ci-dessus restent.
  ///
  /// Contrat commun des `watch…` des dépôts : l'état courant d'abord ; un état
  /// à chaque changement, jamais deux fois le même de suite ; une erreur
  /// (`ServiceFailure`, par exemple `denied` quand le membre perd ses droits)
  /// arrive sur le flux, sans toucher les autres flux. **Firestore** ferme le
  /// flux après l'erreur (une écoute terminée ne reprend pas : l'abonné la
  /// rouvre, voir `LiveReload`) ; **mémoire et drift** le laissent ouvert (une
  /// lecture qui échoue est livrée en erreur, la suivante peut réussir) : un
  /// abonné ne présume pas de la fermeture et rouvre dans tous les cas ;
  /// annuler l'abonnement libère l'écoute ; chaque flux se lit sous le rôle
  /// et le club où il a été ouvert (il se ferme en erreur si ceux-ci
  /// changent).
  Stream<Student?> watchById(StudentId id);

  /// Suit la liste que renvoie [all].
  Stream<List<Student>> watchAll();
}
