import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port étroit : le **nom** des groupes du périmètre du compte, rien d'autre.
///
/// Le seul accès d'un parent ou d'un élève aux groupes : jamais l'agrégat
/// `Group` (appartenances, donc les camarades), jamais le dépôt entier (ADR
/// 0024, décision 26 ; ADR 0025).
abstract interface class GroupNames {
  /// Le nom de chaque groupe du périmètre du compte.
  Future<Map<GroupId, String>> all();

  /// Suit [all] : un état complet à chaque changement.
  Stream<Map<GroupId, String>> watch();
}
