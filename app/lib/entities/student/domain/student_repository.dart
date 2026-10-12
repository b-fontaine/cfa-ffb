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
  /// Crée ou remplace l'élève.
  Future<void> save(Student student);

  Future<Student?> byId(StudentId id);

  Future<List<Student>> all();

  /// Supprime logiquement l'élève ; sans effet s'il n'existe pas.
  Future<void> delete(StudentId id);

  /// Efface physiquement l'élève et son historique de public (droit à
  /// l'effacement) : aucune trace ne subsiste, y compris d'une suppression
  /// logique antérieure ; sans effet s'il n'existe pas.
  Future<void> erase(StudentId id);
}
