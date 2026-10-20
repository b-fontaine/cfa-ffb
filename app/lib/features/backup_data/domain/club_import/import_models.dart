import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les catégories de documents qu'un import écrit (FB7, ADR 0024 décision 19).
///
/// L'ordre est **l'ordre d'écriture** : la saison avant le groupe, la fiche
/// avant ses appartenances. Les quatre dernières catégories dépendent de la
/// fiche de l'élève (`studentExists` / `studentInGroup` lisent la fiche **avant**
/// le lot) : elles ne partent jamais dans le lot qui crée la fiche.
enum ImportCategory {
  seasons,
  groups,
  students,
  memberships,
  seasonArchives,
  plannedSessions,
  sessionRecords,
  attempts,
  acquisitions,
  assessments,
  acknowledgements;

  /// Écrite après que la fiche de l'élève existe sur le serveur.
  bool get needsStudentDocument => switch (this) {
    attempts || acquisitions || assessments || acknowledgements => true,
    _ => false,
  };

  /// Données d'un groupe (tout ce que les règles lient à `groupId`).
  bool get isGroupOwned => switch (this) {
    plannedSessions ||
    sessionRecords ||
    attempts ||
    acquisitions ||
    assessments ||
    acknowledgements => true,
    _ => false,
  };
}

/// Une écriture de document du plan : **une** écriture Firestore.
///
/// [id] est l'identifiant du document dans sa collection (celui du fichier,
/// UUID conservé ; `groupe_élève_début` pour une appartenance). [payload] est
/// l'entité du domaine à écrire ; [group], [season] et [student] sont le
/// propriétaire **dénormalisé** que les règles exigent. [recordedAt] n'existe
/// que pour un passage.
final class ImportWrite {
  const ImportWrite({
    required this.category,
    required this.id,
    required this.payload,
    this.group,
    this.season,
    this.student,
    this.recordedAt,
  });

  final ImportCategory category;
  final String id;
  final Object payload;
  final GroupId? group;
  final SeasonId? season;
  final StudentId? student;
  final DateTime? recordedAt;

  /// Clé stable (catégorie et identifiant) : existence.
  String get key => '${category.name}:$id';

  /// Tout ce qui détermine l'écriture : la clé, le propriétaire dénormalisé
  /// et le **contenu** de l'entité (les entités sont des `freezed` dont
  /// `toString` liste tous les champs). Entre dans l'empreinte du plan : une
  /// reprise qui écrirait autre chose sous les mêmes clés est un autre plan.
  /// [recordedAt] n'y entre pas : il part de l'heure du calcul du plan (qui
  /// change d'un jour de reprise à l'autre) et seul l'ordre du fichier compte.
  String get content =>
      '$key|${group?.value}|${season?.value}|${student?.value}|$payload';
}

/// Un lot : au plus `lotSize - 1` écritures de données et le marqueur, en
/// **un seul lot atomique** envoyé au serveur.
final class ImportLot {
  const ImportLot(this.index, this.writes);

  final int index;
  final List<ImportWrite> writes;
}

/// Que faire d'un groupe du fichier (jamais deviné, ADR 0024 décision 19).
sealed class GroupChoice {
  const GroupChoice();
}

/// Le groupe du fichier devient un **nouveau** groupe du club (même
/// identifiant) ; réservé au directeur et à l'administrateur.
final class CreateGroup extends GroupChoice {
  const CreateGroup();
}

/// Le groupe du fichier est **associé** à un groupe qui existe déjà dans le
/// club : ses séances, saisies et appartenances y sont écrites.
final class UseExistingGroup extends GroupChoice {
  const UseExistingGroup(this.target);

  final GroupId target;
}

/// Décision explicite pour une donnée sans groupe : une séance planifiée du
/// fichier sans groupe (drift l'acceptait, le groupe est obligatoire depuis
/// le 2026-10-18), ou un élève sans groupe dont des données (blocs acquis,
/// bilans, acquittements) n'ont pas de séance pour leur donner un groupe.
sealed class OwnerChoice {
  const OwnerChoice();
}

/// Rattacher au groupe [target] du club **après import** (un groupe créé ou
/// associé).
final class AttachTo extends OwnerChoice {
  const AttachTo(this.target);

  final GroupId target;
}

/// Ne pas importer cette donnée.
final class SkipIt extends OwnerChoice {
  const SkipIt();
}

/// Les décisions de l'animateur, toutes **explicites**.
final class ImportDecisions {
  const ImportDecisions({
    this.groups = const {},
    this.plannedSessions = const {},
    this.students = const {},
    this.confirmedMerges = const {},
    this.restoreConfirmed,
    this.unverifiedConfirmed,
  });

  /// Aucune décision encore.
  static const none = ImportDecisions();

  /// Par groupe du fichier : créer, ou associer à un groupe du club. Un groupe
  /// du fichier **dont l'identifiant existe déjà** dans le club est le même
  /// groupe (UUID) : il n'exige aucun choix.
  final Map<GroupId, GroupChoice> groups;

  /// Par identifiant de séance planifiée **sans groupe** du fichier.
  final Map<String, OwnerChoice> plannedSessions;

  /// Par élève **sans groupe** dont des données n'ont aucun groupe.
  final Map<StudentId, OwnerChoice> students;

  /// Groupes du club que l'animateur accepte de **fusionner** (plusieurs
  /// groupes du fichier associés au même groupe) : sans cela, refusé.
  final Set<GroupId> confirmedMerges;

  /// Nombre d'élèves effacés dont l'animateur confirme le rétablissement ;
  /// doit **égaler** le nombre que le plan annonce.
  final int? restoreConfirmed;

  /// Nombre de fiches qu'un **enseignant** crée sans pouvoir vérifier qu'elles
  /// n'existent pas déjà dans le club hors de ses groupes (invisibles pour
  /// lui) : doit **égaler** le nombre que le plan annonce. Si l'une existe,
  /// les règles refusent le lot entier à l'écriture (rien n'est écrit) et il
  /// faut qu'un gestionnaire importe.
  final int? unverifiedConfirmed;

  ImportDecisions copyWith({
    Map<GroupId, GroupChoice>? groups,
    Map<String, OwnerChoice>? plannedSessions,
    Map<StudentId, OwnerChoice>? students,
    Set<GroupId>? confirmedMerges,
    int? restoreConfirmed,
    int? unverifiedConfirmed,
  }) => ImportDecisions(
    groups: groups ?? this.groups,
    plannedSessions: plannedSessions ?? this.plannedSessions,
    students: students ?? this.students,
    confirmedMerges: confirmedMerges ?? this.confirmedMerges,
    restoreConfirmed: restoreConfirmed ?? this.restoreConfirmed,
    unverifiedConfirmed: unverifiedConfirmed ?? this.unverifiedConfirmed,
  );
}

/// Qui importe : le rôle dans le club et, pour un enseignant, ses groupes.
final class ImportActor {
  const ImportActor(this.role, [this.groups = const {}]);

  /// `director`, `admin` ou `teacher` (un parent ou un élève n'importe pas).
  final Role role;

  /// Les groupes de l'enseignant ; vide pour un gestionnaire.
  final Set<GroupId> groups;

  bool get manages => role == Role.director || role == Role.admin;

  bool get isTeacher => role == Role.teacher;

  /// Un rôle qui peut importer (les règles ouvrent `imports` à eux seuls).
  bool get mayImport => manages || isTeacher;
}

/// Un groupe du club, tel que l'import le voit.
final class InventoryGroup {
  const InventoryGroup(this.seasonId, this.audience);

  final SeasonId seasonId;
  final Audience audience;
}

/// Une saison du club, telle que l'import la voit.
final class InventorySeason {
  const InventorySeason({
    required this.startDate,
    required this.endDate,
    this.closedOn,
  });

  final DateTime startDate;
  final DateTime endDate;
  final DateTime? closedOn;

  bool get isClosed => closedOn != null;
}

/// Ce que le club contient avant l'import, **sans donnée personnelle** :
/// identifiants et dates seulement. Lu par `ClubInventoryReader`, dans le
/// périmètre du rôle (un enseignant ne voit que ses groupes).
final class ClubInventory {
  const ClubInventory({
    this.groups = const {},
    this.seasons = const {},
    this.students = const {},
    this.erasingStudents = const {},
    this.existing = const {},
    this.marker,
  });

  static const empty = ClubInventory();

  final Map<GroupId, InventoryGroup> groups;
  final Map<SeasonId, InventorySeason> seasons;

  /// Les fiches **visibles** et les groupes de chacune (`groupIds`).
  final Map<StudentId, Set<GroupId>> students;

  /// Les fiches dont l'effacement est en cours (marqueur `erasing`).
  final Set<StudentId> erasingStudents;

  /// Par catégorie, les identifiants de documents déjà présents.
  final Map<ImportCategory, Set<String>> existing;

  /// Le marqueur du fichier à importer, s'il existe.
  final ImportMarker? marker;

  bool has(ImportCategory category, String id) =>
      existing[category]?.contains(id) ?? false;
}

/// État d'un import enregistré dans le club (sans donnée personnelle).
enum ImportState { running, done }

/// Le marqueur d'import d'un club pour **un fichier** (`clubs/{c}/imports/{fileId}_{uid}`, propre à son auteur).
///
/// [fileId] est l'empreinte SHA-256 du fichier ; [planId] celle de la liste
/// ordonnée des écritures (un plan différent ne reprend pas un import
/// commencé) ; [done] le nombre de lots **terminés**, avancé dans le **même
/// lot atomique** que les écritures qu'il compte (une écriture de plus ne peut
/// pas être faite deux fois : voir `firestore.rules`).
final class ImportMarker {
  const ImportMarker({
    required this.fileId,
    required this.planId,
    required this.lots,
    required this.done,
    required this.writes,
    required this.restored,
    required this.role,
    this.updatedAt,
  });

  final String fileId;
  final String planId;
  final int lots;
  final int done;
  final int writes;
  final int restored;
  final Role role;
  final DateTime? updatedAt;

  ImportState get state =>
      done >= lots ? ImportState.done : ImportState.running;

  /// Le marqueur après le lot suivant.
  ImportMarker advanced() => ImportMarker(
    fileId: fileId,
    planId: planId,
    lots: lots,
    done: done + 1,
    writes: writes,
    restored: restored,
    role: role,
  );
}
