import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les limites d'un import (réglables pour les tests, jamais par l'animateur).
final class ImportLimits {
  const ImportLimits({
    this.lotSize = 400,
    this.dailyWrites = 10000,
    this.staleAfterDays = 31,
    this.accessBudget = 18,
  }) : assert(
         lotSize >= 2,
         'un lot porte au moins une écriture et le marqueur',
       );

  /// Écritures d'un lot **marqueur compris** (ADR 0024, C2 : 400 au plus, sous
  /// les 500 d'un `WriteBatch`).
  final int lotSize;

  /// Écritures qu'un import se permet par jour : **la moitié** du plafond de
  /// 20 000 écritures par jour du plan Spark (ADR 0024, décision 19), pour que
  /// le club continue de travailler le jour de l'import.
  final int dailyWrites;

  /// Âge au-delà duquel un fichier est dit ancien : une fenêtre de migration
  /// d'environ un mois (C2) ; au-delà, du travail fait depuis l'export risque
  /// d'être absent du fichier `[Prop]`.
  final int staleAfterDays;

  /// Documents **distincts** que les règles lisent (`get`, `exists`,
  /// `getAfter`) pour valider un lot : Firestore en tolère 20 par lot
  /// d'écritures (mesuré à l'émulateur : 19 fiches distinctes pour un
  /// directeur, 18 pour un administrateur ou un enseignant ; un même document
  /// compte une fois), dont le `member` et `admins/{uid}` de l'auteur. Un lot ne cite donc jamais plus
  /// de [accessBudget] fiches ou groupes distincts : sinon les règles refusent
  /// **tout** le lot.
  final int accessBudget;

  /// Écritures de données par lot (le marqueur prend la dernière place).
  int get dataPerLot => lotSize - 1;
}

/// Ce qui est refusé ou à décider, localisé par `import_report_text.dart` : le
/// rapport ne porte **jamais** de texte du fichier (ni prénom, ni nom, ni
/// remarque), seulement un code, une catégorie, un compte et des identifiants
/// techniques.
enum ImportProblemCode {
  /// Le fichier n'est pas une sauvegarde lisible ou n'a pas la forme attendue.
  unreadable,
  versionUnsupported,
  invalid,

  /// Références du catalogue (séance, bloc, exercice) inconnues.
  unknownSheet,
  unknownBlock,
  inconsistentCatalogue,

  /// Cohérence interne du fichier.
  duplicateId,
  danglingReference,
  orphanAttempt,

  /// Bornes du domaine et des règles Firestore.
  badIdentifier,
  valueTooLong,
  valueOutOfRange,
  badDate,
  tooManyPresent,

  /// Contre l'état du club.
  reopensClosedSeason,
  targetSeasonClosed,
  outsideSeason,
  audienceMismatch,
  unknownTargetGroup,
  mergeNotConfirmed,
  invalidDecision,
  studentBeingErased,
  planChanged,

  /// Le rôle n'a pas le droit d'écrire (règles Firestore).
  roleDenied,
}

/// Un problème, regroupé par code et catégorie.
final class ImportProblem {
  const ImportProblem(
    this.code,
    this.category, {
    this.count = 1,
    this.sample = const [],
  });

  final ImportProblemCode code;

  /// La catégorie de documents concernée (`null` : le fichier entier).
  final ImportCategory? category;

  /// Nombre d'éléments en défaut.
  final int count;

  /// Les premiers identifiants techniques (jamais un prénom).
  final List<String> sample;

  @override
  String toString() => 'ImportProblem(${code.name}, ${category?.name}, $count)';
}

/// Avertissements : le plan reste exécutable.
enum ImportWarning {
  /// Le fichier date de plus de `staleAfterDays` jours.
  staleFile,

  /// Plus d'écritures que le budget d'un jour : à fractionner.
  largeImport,

  /// Les réglages du fichier ne sont pas importés (réglages du club partagés).
  settingsIgnored,

  /// Des saisons, groupes ou archives du fichier ne sont pas écrits, faute de
  /// droit (enseignant) : seul le périmètre de l'enseignant est importé.
  roleScope,
}

/// Les compteurs d'une catégorie.
final class ImportCount {
  const ImportCount({
    this.inFile = 0,
    this.writes = 0,
    this.alreadyPresent = 0,
    this.ignored = 0,
  });

  /// Éléments du fichier.
  final int inFile;

  /// Écritures prévues.
  final int writes;

  /// Documents déjà présents dans le club (ils ne sont jamais modifiés).
  final int alreadyPresent;

  /// Éléments écartés par une décision explicite ou par le rôle.
  final int ignored;
}

/// Le rapport d'un import : compteurs par catégorie, premiers problèmes,
/// avertissements. Aucune donnée personnelle (voir [ImportProblemCode]).
final class ImportReport {
  const ImportReport({
    required this.counts,
    this.problems = const [],
    this.warnings = const {},
    this.undecidedGroups = const [],
    this.undecidedSessions = const [],
    this.undecidedStudents = const [],
    this.restoredStudents = 0,
    this.unverifiableStudents = 0,
    this.fileAgeDays,
  });

  final Map<ImportCategory, ImportCount> counts;
  final List<ImportProblem> problems;
  final Set<ImportWarning> warnings;

  /// Groupes du fichier à créer ou associer.
  final List<GroupId> undecidedGroups;

  /// Séances planifiées sans groupe, à rattacher ou ignorer.
  final List<String> undecidedSessions;

  /// Élèves sans groupe dont des données attendent un groupe.
  final List<StudentId> undecidedStudents;

  /// Élèves absents du club que l'import rétablirait (déjà effacés ?).
  final int restoredStudents;

  /// Fiches qu'un enseignant créerait **sans pouvoir vérifier** qu'elles
  /// n'existent pas déjà hors de ses groupes ; zéro pour un gestionnaire.
  final int unverifiableStudents;

  final int? fileAgeDays;

  /// Le même rapport avec un avertissement de plus.
  ImportReport withWarning(ImportWarning warning) => ImportReport(
    counts: counts,
    problems: problems,
    warnings: {...warnings, warning},
    undecidedGroups: undecidedGroups,
    undecidedSessions: undecidedSessions,
    undecidedStudents: undecidedStudents,
    restoredStudents: restoredStudents,
    unverifiableStudents: unverifiableStudents,
    fileAgeDays: fileAgeDays,
  );

  /// Les premiers problèmes, au plus [limit] (affichage).
  List<ImportProblem> firstProblems([int limit = 5]) =>
      problems.take(limit).toList();

  int get totalProblems =>
      problems.fold(0, (total, problem) => total + problem.count);
}

/// Où en est le plan.
enum ImportStatus {
  /// Fichier illisible, incohérent, hors périmètre du rôle : rien à écrire.
  blocked,

  /// Des choix manquent (groupes, séances ou élèves sans groupe).
  needsDecisions,

  /// Des élèves effacés seraient rétablis : confirmation explicite requise.
  needsConfirmation,

  /// Le fichier est déjà entièrement importé dans ce club.
  alreadyImported,

  /// Un import de ce fichier est commencé : reprendre au lot suivant.
  resumable,

  /// Prêt à écrire.
  ready,
}

/// Le plan d'import, calculé **avant** toute écriture.
final class ClubImportPlan {
  const ClubImportPlan({
    required this.status,
    required this.report,
    this.fingerprint = '',
    this.planId = '',
    this.lots = const [],
    this.startLot = 0,
    this.limits = const ImportLimits(),
    this.version,
    this.outline = ImportOutline.empty,
  });

  final ImportStatus status;
  final ImportReport report;

  /// Empreinte du fichier (identifiant du marqueur).
  final String fingerprint;

  /// Empreinte de la liste ordonnée des écritures.
  final String planId;
  final List<ImportLot> lots;

  /// Premier lot à écrire (les précédents sont déjà au club).
  final int startLot;
  final ImportLimits limits;

  /// Version du format du fichier (1 à 5).
  final int? version;

  /// Ce que l'écran montre du fichier pour décider (groupes, séances et
  /// élèves sans groupe) ; vide pour un fichier illisible.
  final ImportOutline outline;

  /// Le même plan avec [outline] (posé par `PrepareClubImport` : le
  /// planificateur ne lit pas le club).
  ClubImportPlan withOutline(ImportOutline outline) => ClubImportPlan(
    status: status,
    report: report,
    fingerprint: fingerprint,
    planId: planId,
    lots: lots,
    startLot: startLot,
    limits: limits,
    version: version,
    outline: outline,
  );

  /// Un import de ce fichier est commencé et le plan ne diffère du sien que par
  /// les choix : l'animateur doit refaire **les mêmes choix** pour le reprendre
  /// (ce n'est pas un fichier refusé).
  bool get awaitsSameChoices =>
      status == ImportStatus.blocked &&
      outline.marker != null &&
      report.problems.isNotEmpty &&
      report.problems.every((p) => p.code == ImportProblemCode.planChanged);

  /// Vrai si le moteur d'écriture peut l'exécuter.
  bool get isRunnable =>
      status == ImportStatus.ready || status == ImportStatus.resumable;

  /// Écritures de données du plan entier.
  int get totalWrites =>
      lots.fold(0, (total, lot) => total + lot.writes.length);

  /// Écritures (marqueur compris) restant à faire.
  int get remainingWrites => lots
      .skip(startLot)
      .fold(0, (total, lot) => total + lot.writes.length + 1);

  /// Nombre de jours nécessaires au budget quotidien (au moins 1).
  int get daysNeeded {
    final remaining = remainingWrites;
    if (remaining == 0) return 0;
    var days = 1;
    var spent = 0;
    for (final lot in lots.skip(startLot)) {
      final cost = lot.writes.length + 1;
      if (spent > 0 && spent + cost > limits.dailyWrites) {
        days++;
        spent = 0;
      }
      spent += cost;
    }
    return days;
  }
}
