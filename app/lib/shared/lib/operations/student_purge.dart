import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';

/// Ce qu'un effacement va supprimer pour un élève : des **nombres**, jamais un
/// identifiant ni un contenu (aperçu des effets avant la confirmation).
final class StudentPurgePreview {
  const StudentPurgePreview({
    this.attempts = 0,
    this.acquisitions = 0,
    this.assessments = 0,
    this.acknowledgements = 0,
    this.memberships = 0,
    this.presences = 0,
    this.accountLinks = 0,
  });

  final int attempts;
  final int acquisitions;
  final int assessments;
  final int acknowledgements;
  final int memberships;

  /// Séances où l'élève figure parmi les présents.
  final int presences;

  /// Comptes (parent ou élève) liés à cette fiche.
  final int accountLinks;

  int get total =>
      attempts +
      acquisitions +
      assessments +
      acknowledgements +
      memberships +
      presences +
      accountLinks;
}

/// Port : la purge **par lots** des données d'un élève dans le club (ADR 0024,
/// décision 19 ; ADR 0019 ; ADR 0025). Une seule liste de ce qui se rapporte à
/// un élève, pour l'effacement d'un élève **et** pour la clôture de saison.
///
/// Rien ici n'est atomique : chaque lot rendu l'est (c'est le magasin
/// d'opérations qui l'applique avec le marqueur), et chaque écriture est
/// idempotente (suppression, retrait d'un élément de liste par `arrayRemove`,
/// jamais lecture puis écriture), donc rejouable.
abstract interface class StudentPurge {
  /// Ce qui se rapporte à [id], compté sans rien lire d'autre.
  Future<StudentPurgePreview> preview(StudentId id);

  /// La fiche de [id] existe-t-elle encore ?
  Future<bool> exists(StudentId id);

  /// Les fiches marquées « effacement en cours » (`erasing`) que le compte
  /// courant voit.
  Future<Set<StudentId>> flagged();

  /// Le lot qui marque [ids] « effacement en cours » : la fiche reste, sans
  /// donnée de plus, et **plus aucune donnée nouvelle ne s'y rapporte** (les
  /// règles les refusent). Irréversible.
  OperationLot flag(Set<StudentId> ids);

  /// Les lots qui restent pour purger les données liées à [ids] **hors les
  /// fiches**, de [maxWrites] écritures au plus chacun (regroupées d'un élève à
  /// l'autre), recalculés d'après l'état courant (vide quand tout est purgé).
  /// L'accès des comptes parent et élève est coupé **en premier**.
  Future<List<OperationLot>> purgeLots(
    Set<StudentId> ids, {
    required int maxWrites,
  });

  /// Le lot qui supprime les fiches [ids], **en dernier** : aucune trace de
  /// l'effacement ne reste.
  OperationLot removeRecords(Set<StudentId> ids);
}
