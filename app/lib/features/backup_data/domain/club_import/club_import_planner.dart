import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session_record/domain/sitting_id.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_integrity.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/document_ids.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';

/// Une fiche à écrire : l'élève et les groupes **courants** (appartenances
/// ouvertes, après correspondance des groupes) que `groupIds` dénormalise.
final class ImportStudent {
  const ImportStudent(this.student, this.groupIds);

  final Student student;
  final Set<GroupId> groupIds;

  @override
  String toString() =>
      'ImportStudent($student, '
      '${([for (final g in groupIds) g.value]..sort()).join(',')})';
}

/// Une appartenance à écrire, dans le groupe **du club** (créé ou associé).
final class ImportMembership {
  const ImportMembership(this.group, this.season, this.membership);

  final GroupId group;
  final SeasonId season;
  final Membership membership;

  @override
  String toString() =>
      'ImportMembership(${group.value}, ${season.value}, $membership)';
}

/// Un document d'archive de saison : la synthèse d'un public, ou un exercice.
final class ImportArchiveDoc {
  const ImportArchiveDoc.summary(this.season, AudienceArchive this.block)
    : line = null;

  const ImportArchiveDoc.exercise(this.season, ExerciseArchive this.line)
    : block = null;

  final SeasonId season;
  final AudienceArchive? block;
  final ExerciseArchive? line;

  @override
  String toString() => 'ImportArchiveDoc(${season.value}, $block, $line)';
}

/// Tout ce que le plan lit : le fichier, le club, les décisions, le rôle.
final class ClubImportInput {
  const ClubImportInput({
    required this.actor,
    required this.now,
    this.snapshot,
    this.fingerprint = '',
    this.version,
    this.exportedAt,
    this.inventory = ClubInventory.empty,
    this.decisions = ImportDecisions.none,
    this.limits = const ImportLimits(),
    this.preProblems = const [],
    this.newerFileStudents,
  });

  /// `null` : le fichier n'a pas pu être lu ([preProblems] dit pourquoi).
  final BackupSnapshot? snapshot;
  final String fingerprint;
  final int? version;
  final DateTime? exportedAt;
  final ImportActor actor;
  final ClubInventory inventory;
  final ImportDecisions decisions;
  final DateTime now;
  final ImportLimits limits;

  /// Problèmes déjà constatés avant le plan (décodage, catalogue).
  final List<ImportProblem> preProblems;

  /// Les élèves d'une sauvegarde **plus récente** que le fichier, si
  /// l'animateur en fournit une : un élève du fichier qui n'y figure plus et
  /// qui est absent du club a vraisemblablement été effacé.
  final Set<StudentId>? newerFileStudents;
}

class _Resolved {
  const _Resolved({
    required this.fileId,
    required this.target,
    required this.season,
    required this.audience,
    required this.exists,
    required this.write,
  });

  final GroupId fileId;
  final GroupId target;
  final SeasonId season;
  final Audience audience;

  /// Le groupe existe déjà dans le club.
  final bool exists;

  /// Le plan écrit ce groupe (créé).
  final bool write;
}

class _SeasonView {
  const _SeasonView(this.start, this.end, {required this.closed});

  final DateTime start;
  final DateTime end;
  final bool closed;

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
}

/// Calcule le **plan d'import** d'une sauvegarde vers un club synchronisé
/// (FB7, ADR 0024 décision 19 et C2), **avant toute écriture** : en pur Dart,
/// sans lire ni écrire le club (l'état du club est [ClubInventory]).
///
/// - **intégrité** ([ImportIntegrity]) puis **état du club** : groupes,
///   saisons closes, décisions manquantes ;
/// - **correspondance des groupes** : créer, ou associer à un groupe existant ;
///   jamais deux groupes fusionnés sans choix explicite ; un enseignant n'écrit
///   que dans **ses** groupes ;
/// - **décisions explicites** pour une séance planifiée sans groupe et pour
///   l'élève sans groupe dont les données n'ont pas de séance : le plan ne
///   devine jamais ;
/// - **droits** ([_denied]) : les écritures que le rôle n'a pas le droit de
///   faire sont dites **avant** d'écrire (miroir des règles, prouvé contre
///   l'émulateur) ;
/// - **élèves effacés** : ce que le club permet de détecter est compté, et
///   la confirmation doit égaler ce nombre ;
/// - **lots** : unités atomiques (la fiche et ses appartenances ne se séparent
///   pas) ; fiche avant ses données ; 400 écritures au plus marqueur compris ;
///   le **plan est déterministe** (même fichier, mêmes décisions, même rôle :
///   mêmes lots), ce qui rend la reprise possible ; l'existence de documents
///   ne change jamais le plan, elle est appliquée à l'écriture.
final class ClubImportPlanner {
  const ClubImportPlanner();

  ClubImportPlan plan(ClubImportInput input) {
    final snapshot = input.snapshot;
    final problems = ProblemCollector();
    input.preProblems.forEach(problems.merge);
    if (!input.actor.mayImport) {
      problems.add(ImportProblemCode.roleDenied, null);
    }
    if (snapshot == null || !problems.isEmpty) {
      return _blocked(input, problems, snapshot);
    }
    final marker = input.inventory.marker;
    if (marker != null && marker.state == ImportState.done) {
      return ClubImportPlan(
        status: ImportStatus.alreadyImported,
        report: _report(input, snapshot, const {}, []),
        fingerprint: input.fingerprint,
        planId: marker.planId,
        limits: input.limits,
        version: input.version,
      );
    }
    const ImportIntegrity().check(snapshot).build().forEach(problems.merge);
    if (!problems.isEmpty) return _blocked(input, problems, snapshot);

    final seasons = _seasonViews(snapshot, input.inventory);
    final undecided = _Undecided();
    final resolved = _resolveGroups(
      input,
      snapshot,
      seasons,
      problems,
      undecided,
    );
    for (final id in input.inventory.erasingStudents) {
      if (snapshot.students.any((s) => s.id == id)) {
        problems.add(
          ImportProblemCode.studentBeingErased,
          ImportCategory.students,
          id.value,
        );
      }
    }
    if (!problems.isEmpty || undecided.groups.isNotEmpty) {
      return _unfinished(input, snapshot, problems, undecided);
    }
    final built = _Builder(
      input,
      snapshot,
      resolved,
      seasons,
      problems,
      undecided,
    )..build();
    if (!problems.isEmpty) return _blocked(input, problems, snapshot);
    if (undecided.any) return _unfinished(input, snapshot, problems, undecided);

    final denied = _denied(input.actor, input.inventory, built.writes);
    for (final entry in denied.entries) {
      problems.add(
        ImportProblemCode.roleDenied,
        entry.key,
        entry.value.first,
        entry.value.length,
      );
    }
    if (!problems.isEmpty) return _blocked(input, problems, snapshot);

    final lots = _lots(built.writes, input.limits, input.actor);
    final planId = _planId(input, lots);
    var startLot = 0;
    var status = ImportStatus.ready;
    final restored = marker == null
        ? _restored(input, snapshot)
        : <StudentId>{};
    // Un enseignant ne voit que les fiches de ses groupes : une fiche déjà
    // présente hors d'eux lui est invisible et le plan la croit neuve.
    final unverifiable = marker == null
        ? _unverifiable(input.actor, input.inventory, built.writes)
        : 0;
    if (marker != null) {
      if (marker.planId != planId || marker.lots != lots.length) {
        problems.add(ImportProblemCode.planChanged, null);
        return _blocked(input, problems, snapshot);
      }
      startLot = marker.done;
      status = ImportStatus.resumable;
    } else if ((restored.isNotEmpty &&
            input.decisions.restoreConfirmed != restored.length) ||
        (unverifiable > 0 &&
            input.decisions.unverifiedConfirmed != unverifiable)) {
      status = ImportStatus.needsConfirmation;
    }
    final plan = ClubImportPlan(
      status: status,
      report: _report(
        input,
        snapshot,
        built.counts(input.inventory),
        problems.build(),
        restored: restored.length,
        unverifiable: unverifiable,
        ignoredByRole: built.roleScope,
      ),
      fingerprint: input.fingerprint,
      planId: planId,
      lots: status == ImportStatus.needsConfirmation ? const [] : lots,
      startLot: startLot,
      limits: input.limits,
      version: input.version,
    );
    if (!plan.isRunnable || plan.daysNeeded <= 1) return plan;
    return ClubImportPlan(
      status: plan.status,
      report: plan.report.withWarning(ImportWarning.largeImport),
      fingerprint: plan.fingerprint,
      planId: plan.planId,
      lots: plan.lots,
      startLot: plan.startLot,
      limits: plan.limits,
      version: plan.version,
    );
  }

  /// L'identité du plan : le fichier, la taille des lots, **toutes les
  /// décisions** et le **contenu** de chaque écriture, lot par lot. Une reprise
  /// avec une autre correspondance de groupes, un autre rattachement ou une
  /// autre portée est donc un autre plan (`planChanged`), jamais un état
  /// mélangé. La confirmation des élèves effacés n'y entre pas : elle ne fait
  /// que rendre le plan exécutable, et ce qu'elle rétablit est déjà dans les
  /// écritures.
  static String _planId(ClubImportInput input, List<ImportLot> lots) {
    final decisions = input.decisions;
    String ids(Iterable<String> values) => (values.toList()..sort()).join(',');
    String choice(Object? choice) => switch (choice) {
      CreateGroup() => 'create',
      UseExistingGroup(:final target) => 'use:${target.value}',
      AttachTo(:final target) => 'attach:${target.value}',
      SkipIt() => 'skip',
      _ => '?',
    };
    String table<K>(Map<K, Object?> map, String Function(K) key) => ids([
      for (final entry in map.entries)
        '${key(entry.key)}=${choice(entry.value)}',
    ]);
    final content = lots
        .map((lot) => lot.writes.map((w) => w.content).join('\n'))
        .join('\u0001');
    return sha256Hex(
      '${input.fingerprint}|${input.limits.lotSize}|'
      'groups:${table<GroupId>(decisions.groups, (g) => g.value)}|'
      'sessions:${table<String>(decisions.plannedSessions, (s) => s)}|'
      'students:${table<StudentId>(decisions.students, (s) => s.value)}|'
      'merges:${ids(decisions.confirmedMerges.map((g) => g.value))}|'
      '$content',
    );
  }

  /// Pour les tests contre les règles Firestore : les écritures que le plan
  /// ferait pour `input.actor`, et, par catégorie, les identifiants de celles
  /// que [analyzedFor] (par défaut le même acteur) n'aurait **pas le droit** de
  /// faire. `null` si le plan ne va pas jusqu'aux écritures (fichier refusé,
  /// choix manquants). Un fichier construit pour un gestionnaire et analysé
  /// pour un enseignant donne tout ce que le gestionnaire écrirait et ce que
  /// les règles refuseraient à l'enseignant.
  ({List<ImportWrite> writes, Map<ImportCategory, List<String>> denied})?
  explain(ClubImportInput input, {ImportActor? analyzedFor}) {
    final snapshot = input.snapshot;
    if (snapshot == null) return null;
    final problems = ProblemCollector();
    const ImportIntegrity().check(snapshot).build().forEach(problems.merge);
    if (!problems.isEmpty) return null;
    final seasons = _seasonViews(snapshot, input.inventory);
    final undecided = _Undecided();
    final resolved = _resolveGroups(
      input,
      snapshot,
      seasons,
      problems,
      undecided,
    );
    if (!problems.isEmpty || undecided.groups.isNotEmpty) return null;
    final built = _Builder(
      input,
      snapshot,
      resolved,
      seasons,
      problems,
      undecided,
    )..build();
    if (!problems.isEmpty || undecided.any) return null;
    return (
      writes: built.writes,
      denied: _denied(
        analyzedFor ?? input.actor,
        input.inventory,
        built.writes,
      ),
    );
  }

  // ───────────────────────── Résolution ─────────────────────────

  Map<SeasonId, _SeasonView> _seasonViews(
    BackupSnapshot snapshot,
    ClubInventory inventory,
  ) => {
    for (final s in snapshot.seasons)
      s.id: _SeasonView(s.startDate, s.endDate, closed: s.isClosed),
    for (final entry in inventory.seasons.entries)
      entry.key: _SeasonView(
        entry.value.startDate,
        entry.value.endDate,
        closed: entry.value.isClosed,
      ),
  };

  Map<GroupId, _Resolved> _resolveGroups(
    ClubImportInput input,
    BackupSnapshot snapshot,
    Map<SeasonId, _SeasonView> seasons,
    ProblemCollector problems,
    _Undecided undecided,
  ) {
    final inventory = input.inventory;
    final actor = input.actor;
    final resolved = <GroupId, _Resolved>{};
    for (final season in snapshot.seasons) {
      final club = inventory.seasons[season.id];
      if (club != null && club.isClosed && !season.isClosed) {
        problems.add(
          ImportProblemCode.reopensClosedSeason,
          ImportCategory.seasons,
          season.id.value,
        );
      }
    }
    for (final group in snapshot.groups) {
      final choice = input.decisions.groups[group.id];
      final club = inventory.groups[group.id];
      _Resolved? result;
      switch (choice) {
        case null when club != null:
        case CreateGroup() when club != null:
          result = _Resolved(
            fileId: group.id,
            target: group.id,
            season: club.seasonId,
            audience: club.audience,
            exists: true,
            write: choice != null,
          );
        case null:
          undecided.groups.add(group.id);
        case CreateGroup():
          result = _Resolved(
            fileId: group.id,
            target: group.id,
            season: group.seasonId,
            audience: group.audience,
            exists: false,
            write: true,
          );
        case UseExistingGroup(:final target):
          final existing = inventory.groups[target];
          if (!actor.mayWriteTo(target)) {
            // Hors de ses groupes : un enseignant ne voit même pas ce groupe
            // (les règles le lui cachent), donc l'écriture lui est refusée.
            problems.add(
              ImportProblemCode.roleDenied,
              ImportCategory.groups,
              group.id.value,
            );
          } else if (existing == null) {
            problems.add(
              ImportProblemCode.unknownTargetGroup,
              ImportCategory.groups,
              group.id.value,
            );
          } else {
            result = _Resolved(
              fileId: group.id,
              target: target,
              season: existing.seasonId,
              audience: existing.audience,
              exists: true,
              write: false,
            );
          }
      }
      if (result == null) continue;
      resolved[group.id] = result;
      if (result.audience != group.audience) {
        problems.add(
          ImportProblemCode.audienceMismatch,
          ImportCategory.groups,
          group.id.value,
        );
      }
      // Du travail nouveau n'entre pas dans une saison close ici : seul le
      // groupe **associé** est concerné (un groupe créé l'est dans la saison du
      // fichier, close ou non : c'est de l'histoire).
      if (choice is UseExistingGroup &&
          (inventory.seasons[result.season]?.isClosed ?? false)) {
        problems.add(
          ImportProblemCode.targetSeasonClosed,
          ImportCategory.groups,
          group.id.value,
        );
      }
      if (actor.isTeacher &&
          (result.write && !result.exists ||
              !actor.groups.contains(result.target))) {
        problems.add(
          ImportProblemCode.roleDenied,
          ImportCategory.groups,
          group.id.value,
        );
      }
    }
    final fileGroupsOf = <GroupId, int>{};
    for (final r in resolved.values) {
      fileGroupsOf.update(r.target, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final entry in fileGroupsOf.entries) {
      if (entry.value > 1 &&
          !input.decisions.confirmedMerges.contains(entry.key)) {
        problems.add(
          ImportProblemCode.mergeNotConfirmed,
          ImportCategory.groups,
          entry.key.value,
        );
      }
    }
    return resolved;
  }

  // ───────────────────────── Élèves effacés ─────────────────────────

  /// Les élèves que cet import rétablirait peut-être, **d'après ce que le club
  /// permet de voir** : voir `docs/engineering/adr/0019` (limites) et la note
  /// FB7a de l'ADR 0024 pour ce qui n'est pas détectable.
  Set<StudentId> _restored(ClubImportInput input, BackupSnapshot snapshot) {
    final inventory = input.inventory;
    final absent = {
      for (final s in snapshot.students)
        if (!inventory.students.containsKey(s.id)) s.id,
    };
    if (absent.isEmpty) return const {};
    final suspects = <StudentId>{};
    final exported = input.exportedAt;
    final exportDay = exported == null
        ? null
        : DateTime(exported.year, exported.month, exported.day);
    final closedAfterExport = inventory.seasons.values.any(
      (season) =>
          season.isClosed &&
          (exportDay == null || !season.closedOn!.isBefore(exportDay)),
    );
    if (closedAfterExport) suspects.addAll(absent);
    final newer = input.newerFileStudents;
    if (newer != null) {
      suspects.addAll(absent.where((id) => !newer.contains(id)));
    }
    return suspects;
  }

  // ───────────────────────── Droits ─────────────────────────

  /// Les fiches qu'un **enseignant** créerait sans pouvoir savoir si elles
  /// existent déjà : celles du fichier qu'il ne voit pas (l'inventaire d'un
  /// enseignant ne liste que les fiches de ses groupes, et les règles lui
  /// refusent la lecture d'une fiche hors de ses groupes comme celle d'une
  /// fiche absente). Zéro pour un gestionnaire, qui lit tout le club.
  int _unverifiable(
    ImportActor actor,
    ClubInventory inventory,
    List<ImportWrite> writes,
  ) {
    if (!actor.isTeacher) return 0;
    return writes
        .where(
          (w) =>
              w.category == ImportCategory.students &&
              !inventory.students.containsKey(
                (w.payload as ImportStudent).student.id,
              ),
        )
        .length;
  }

  /// Pour chaque catégorie, les identifiants des écritures que le rôle n'a pas
  /// le droit de faire : **le miroir de `firestore.rules`** (jeu de tests
  /// `import.test.mjs`, qui joue le plan contre les vraies règles).
  Map<ImportCategory, List<String>> _denied(
    ImportActor actor,
    ClubInventory inventory,
    List<ImportWrite> writes,
  ) {
    final denied = <ImportCategory, List<String>>{};
    if (actor.manages) return denied;
    void deny(ImportWrite write) =>
        (denied[write.category] ??= []).add(write.id);
    final membershipsOf = <StudentId, List<ImportWrite>>{};
    for (final write in writes) {
      if (write.category == ImportCategory.memberships) {
        (membershipsOf[write.student!] ??= []).add(write);
      }
    }
    final groupsOf = <StudentId, Set<GroupId>>{};
    for (final write in writes) {
      if (write.category != ImportCategory.students) continue;
      final student = write.payload as ImportStudent;
      final id = student.student.id;
      final known = inventory.students[id];
      if (known != null) groupsOf[id] = known;
      if (known != null) {
        if (!known.containsAll(student.groupIds)) deny(write);
        for (final m in membershipsOf[id] ?? const <ImportWrite>[]) {
          if (!inventory.has(ImportCategory.memberships, m.id)) deny(m);
        }
        continue;
      }
      final first = student.student.audienceHistory.first.effectiveFrom;
      final memberships = membershipsOf[id] ?? const <ImportWrite>[];
      final enrollable =
          student.groupIds.isNotEmpty &&
          actor.groups.containsAll(student.groupIds) &&
          memberships.every((m) {
            final membership = (m.payload as ImportMembership).membership;
            return membership.to == null &&
                actor.groups.contains(m.group) &&
                membership.from == first;
          });
      // Une fiche refusée n'existera pas : ses données n'ont pas de fiche à
      // lire (`studentInGroup`), elles sont refusées avec elle.
      groupsOf[id] = enrollable ? student.groupIds : const {};
      if (!enrollable) {
        deny(write);
        memberships.forEach(deny);
      }
    }
    for (final write in writes) {
      switch (write.category) {
        case ImportCategory.seasons ||
            ImportCategory.groups ||
            ImportCategory.seasonArchives:
          deny(write);
        case ImportCategory.students || ImportCategory.memberships:
          break;
        case ImportCategory.plannedSessions || ImportCategory.sessionRecords:
          if (!inventory.has(write.category, write.id) &&
              !actor.groups.contains(write.group)) {
            deny(write);
          }
        case ImportCategory.attempts ||
            ImportCategory.acquisitions ||
            ImportCategory.assessments ||
            ImportCategory.acknowledgements:
          final inGroup =
              write.student != null &&
              (groupsOf[write.student!] ?? const {}).contains(write.group);
          if (!inventory.has(write.category, write.id) &&
              !(actor.groups.contains(write.group) && inGroup)) {
            deny(write);
          }
      }
    }
    return denied;
  }

  // ───────────────────────── Lots ─────────────────────────

  List<ImportLot> _lots(
    List<ImportWrite> writes,
    ImportLimits limits,
    ImportActor actor,
  ) {
    // Unités atomiques : une fiche et ses appartenances partent ensemble.
    final units = <List<ImportWrite>>[];
    final memberships = <StudentId, List<ImportWrite>>{};
    for (final write in writes) {
      if (write.category == ImportCategory.memberships) {
        (memberships[write.student!] ??= []).add(write);
      }
    }
    for (final write in writes) {
      switch (write.category) {
        case ImportCategory.memberships:
          break;
        case ImportCategory.students:
          units.add([write, ...?memberships[write.student]]);
        case ImportCategory.seasons ||
            ImportCategory.groups ||
            ImportCategory.seasonArchives ||
            ImportCategory.plannedSessions ||
            ImportCategory.sessionRecords ||
            ImportCategory.attempts ||
            ImportCategory.acquisitions ||
            ImportCategory.assessments ||
            ImportCategory.acknowledgements:
          units.add([write]);
      }
    }
    final lots = <ImportLot>[];
    var current = <ImportWrite>[];
    var accessed = <String>{};
    var dependent = false;
    void flush() {
      if (current.isNotEmpty) lots.add(ImportLot(lots.length, current));
      current = [];
      accessed = {};
    }

    for (final unit in units) {
      final needsStudent = unit.first.category.needsStudentDocument;
      if (needsStudent != dependent) {
        flush();
        dependent = needsStudent;
      }
      final keys = _accessKeys(actor, unit);
      if (current.length + unit.length > limits.dataPerLot ||
          accessed.union(keys).length > limits.accessBudget) {
        flush();
      }
      current.addAll(unit);
      accessed.addAll(keys);
    }
    flush();
    return lots;
  }

  /// Les documents que les règles lisent pour valider [unit] (`firestore.rules`
  /// : `studentExists`, `studentInGroup`, `teacherEnrolls`), pour [actor] : le
  /// plan s'en sert pour qu'un lot ne dépasse jamais le budget de lectures des
  /// règles. Le `member` et `admins/{uid}` de l'auteur sont hors de ce compte
  /// (voir `ImportLimits.accessBudget`).
  Set<String> _accessKeys(ImportActor actor, List<ImportWrite> unit) {
    final keys = <String>{};
    for (final write in unit) {
      final student = write.student;
      if (write.category.needsStudentDocument && student != null) {
        // `exists(fiche)` d'un gestionnaire, `get(fiche)` d'un enseignant.
        keys.add('student:${student.value}');
      } else if (!actor.manages &&
          write.category == ImportCategory.students &&
          student != null) {
        // `exists(fiche)` et `getAfter(fiche)` de `teacherEnrolls` : un même
        // document, compté une fois (mesuré à l'émulateur : 17 fiches neuves
        // et leur groupe dans un lot, pas 18).
        keys.add('student:${student.value}');
      } else if (!actor.manages &&
          write.category == ImportCategory.memberships &&
          write.group != null) {
        // `get(groupe)` de `teacherEnrolls`, partagé par les fiches du groupe.
        keys.add('group:${write.group!.value}');
      }
    }
    return keys;
  }

  // ───────────────────────── Rapport ─────────────────────────

  ClubImportPlan _blocked(
    ClubImportInput input,
    ProblemCollector problems,
    BackupSnapshot? snapshot,
  ) => ClubImportPlan(
    status: ImportStatus.blocked,
    report: _report(input, snapshot, const {}, problems.build()),
    fingerprint: input.fingerprint,
    limits: input.limits,
    version: input.version,
  );

  ClubImportPlan _unfinished(
    ClubImportInput input,
    BackupSnapshot snapshot,
    ProblemCollector problems,
    _Undecided undecided,
  ) => ClubImportPlan(
    status: problems.isEmpty
        ? ImportStatus.needsDecisions
        : ImportStatus.blocked,
    report: _report(
      input,
      snapshot,
      const {},
      problems.build(),
      undecided: undecided,
    ),
    fingerprint: input.fingerprint,
    limits: input.limits,
    version: input.version,
  );

  ImportReport _report(
    ClubImportInput input,
    BackupSnapshot? snapshot,
    Map<ImportCategory, ImportCount> counts,
    List<ImportProblem> problems, {
    _Undecided? undecided,
    int restored = 0,
    int unverifiable = 0,
    int ignoredByRole = 0,
  }) {
    final exported = input.exportedAt;
    final age = exported == null ? null : input.now.difference(exported).inDays;
    return ImportReport(
      counts: counts.isNotEmpty ? counts : _fileCounts(snapshot),
      problems: problems,
      warnings: {
        if (age != null && age > input.limits.staleAfterDays)
          ImportWarning.staleFile,
        if (snapshot?.settings != null) ImportWarning.settingsIgnored,
        if (ignoredByRole > 0) ImportWarning.roleScope,
      },
      undecidedGroups: undecided?.groups ?? const [],
      undecidedSessions: undecided?.sessions ?? const [],
      undecidedStudents: undecided?.students ?? const [],
      restoredStudents: restored,
      unverifiableStudents: unverifiable,
      fileAgeDays: age,
    );
  }

  Map<ImportCategory, ImportCount> _fileCounts(BackupSnapshot? snapshot) {
    if (snapshot == null) return const {};
    return {
      ImportCategory.seasons: ImportCount(inFile: snapshot.seasons.length),
      ImportCategory.groups: ImportCount(inFile: snapshot.groups.length),
      ImportCategory.students: ImportCount(inFile: snapshot.students.length),
      ImportCategory.memberships: ImportCount(
        inFile: snapshot.groups.fold(0, (n, g) => n + g.memberships.length),
      ),
      ImportCategory.seasonArchives: ImportCount(
        inFile: snapshot.seasonArchives.length,
      ),
      ImportCategory.plannedSessions: ImportCount(
        inFile: snapshot.plannedSessions.length,
      ),
      ImportCategory.sessionRecords: ImportCount(
        inFile: snapshot.sessionRecords.length,
      ),
      ImportCategory.attempts: ImportCount(inFile: snapshot.attempts.length),
      ImportCategory.acquisitions: ImportCount(
        inFile: snapshot.blockAcquisitions.length,
      ),
      ImportCategory.assessments: ImportCount(
        inFile: snapshot.assessments.length,
      ),
      ImportCategory.acknowledgements: ImportCount(
        inFile: snapshot.alertAcknowledgements?.length ?? 0,
      ),
    };
  }
}

class _Undecided {
  final groups = <GroupId>[];
  final sessions = <String>[];
  final students = <StudentId>[];

  bool get any => sessions.isNotEmpty || students.isNotEmpty;
}

/// Construit les écritures, dans l'ordre des catégories.
class _Builder {
  _Builder(
    this.input,
    this.snapshot,
    this.resolved,
    this.seasons,
    this.problems,
    this.undecided,
  );

  final ClubImportInput input;
  final BackupSnapshot snapshot;
  final Map<GroupId, _Resolved> resolved;
  final Map<SeasonId, _SeasonView> seasons;
  final ProblemCollector problems;
  final _Undecided undecided;

  final writes = <ImportWrite>[];
  final _ignored = <ImportCategory, int>{};
  int roleScope = 0;

  void _ignore(ImportCategory category) =>
      _ignored.update(category, (n) => n + 1, ifAbsent: () => 1);

  Map<ImportCategory, ImportCount> counts(ClubInventory inventory) {
    final result = <ImportCategory, ImportCount>{};
    for (final category in ImportCategory.values) {
      final own = writes.where((w) => w.category == category).toList();
      result[category] = ImportCount(
        inFile: _inFile(category),
        writes: own.length,
        alreadyPresent: own.where((w) => inventory.has(category, w.id)).length,
        ignored: _ignored[category] ?? 0,
      );
    }
    return result;
  }

  int _inFile(ImportCategory category) => switch (category) {
    ImportCategory.seasons => snapshot.seasons.length,
    ImportCategory.groups => snapshot.groups.length,
    ImportCategory.students => snapshot.students.length,
    ImportCategory.memberships => snapshot.groups.fold(
      0,
      (n, g) => n + g.memberships.length,
    ),
    ImportCategory.seasonArchives => snapshot.seasonArchives.fold(
      0,
      (n, a) => n + a.audiences.length + a.exercises.length,
    ),
    ImportCategory.plannedSessions => snapshot.plannedSessions.length,
    ImportCategory.sessionRecords => snapshot.sessionRecords.length,
    ImportCategory.attempts => snapshot.attempts.length,
    ImportCategory.acquisitions => snapshot.blockAcquisitions.length,
    ImportCategory.assessments => snapshot.assessments.length,
    ImportCategory.acknowledgements =>
      snapshot.alertAcknowledgements?.length ?? 0,
  };

  void build() {
    final manages = input.actor.manages;
    if (manages) {
      _seasons();
      _groups();
    } else {
      roleScope += snapshot.seasons.length + snapshot.seasonArchives.length;
    }
    final memberships = _memberships();
    _students(memberships);
    if (manages) _archives();
    _plannedSessions();
    final recordOwner = _records();
    _attempts(recordOwner);
    _studentData();
  }

  void _seasons() {
    for (final season in snapshot.seasons) {
      writes.add(
        ImportWrite(
          category: ImportCategory.seasons,
          id: season.id.value,
          payload: season,
          season: season.id,
        ),
      );
    }
  }

  void _groups() {
    for (final group in snapshot.groups) {
      final r = resolved[group.id]!;
      if (!r.write) continue;
      writes.add(
        ImportWrite(
          category: ImportCategory.groups,
          id: r.target.value,
          payload: group.copyWith(memberships: const []),
          group: r.target,
          season: r.season,
        ),
      );
    }
  }

  /// Les appartenances par élève, dans le groupe du club.
  Map<StudentId, List<ImportMembership>> _memberships() {
    final byStudent = <StudentId, List<ImportMembership>>{};
    final seen = <String>{};
    for (final group in snapshot.groups) {
      final r = resolved[group.id]!;
      for (final m in group.memberships) {
        final id = DocumentIds.membership(r.target, m.studentId, m.from);
        if (!seen.add(id)) continue;
        (byStudent[m.studentId] ??= []).add(
          ImportMembership(r.target, r.season, m),
        );
      }
    }
    return byStudent;
  }

  void _students(Map<StudentId, List<ImportMembership>> memberships) {
    for (final student in snapshot.students) {
      final own = memberships[student.id] ?? const <ImportMembership>[];
      writes.add(
        ImportWrite(
          category: ImportCategory.students,
          id: student.id.value,
          payload: ImportStudent(student, {
            for (final m in own)
              if (m.membership.to == null) m.group,
          }),
          student: student.id,
        ),
      );
      for (final m in own) {
        writes.add(
          ImportWrite(
            category: ImportCategory.memberships,
            id: DocumentIds.membership(m.group, student.id, m.membership.from),
            payload: m,
            group: m.group,
            season: m.season,
            student: student.id,
          ),
        );
      }
    }
    _groupsOfStudent
      ..clear()
      ..addAll({
        for (final entry in memberships.entries)
          entry.key: [for (final m in entry.value) m.group],
      });
  }

  final _groupsOfStudent = <StudentId, List<GroupId>>{};

  void _archives() {
    for (final archive in snapshot.seasonArchives) {
      for (final block in archive.audiences) {
        writes.add(
          ImportWrite(
            category: ImportCategory.seasonArchives,
            id: DocumentIds.archiveSummary(archive.seasonId, block.audience),
            payload: ImportArchiveDoc.summary(archive.seasonId, block),
            season: archive.seasonId,
          ),
        );
      }
      for (final line in archive.exercises) {
        writes.add(
          ImportWrite(
            category: ImportCategory.seasonArchives,
            id: DocumentIds.archiveExercise(
              archive.seasonId,
              line.audience,
              line.exercise,
            ),
            payload: ImportArchiveDoc.exercise(archive.seasonId, line),
            season: archive.seasonId,
          ),
        );
      }
    }
  }

  /// Le groupe du club et la saison d'un groupe du club **après import** : un
  /// groupe du fichier (créé ou associé) ou un groupe qui existe déjà.
  ({GroupId group, SeasonId season, Audience audience})? _target(GroupId id) {
    for (final r in resolved.values) {
      if (r.target == id) {
        return (group: r.target, season: r.season, audience: r.audience);
      }
    }
    final club = input.inventory.groups[id];
    return club == null
        ? null
        : (group: id, season: club.seasonId, audience: club.audience);
  }

  void _plannedSessions() {
    for (final planned in snapshot.plannedSessions) {
      GroupId? groupId;
      final fileGroup = planned.groupId;
      if (fileGroup != null) {
        groupId = resolved[fileGroup]!.target;
      } else {
        switch (input.decisions.plannedSessions[planned.id]) {
          case null:
            undecided.sessions.add(planned.id);
            continue;
          case SkipIt():
            _ignore(ImportCategory.plannedSessions);
            continue;
          case AttachTo(:final target):
            groupId = target;
        }
      }
      final target = _target(groupId);
      if (target == null) {
        problems.add(
          ImportProblemCode.invalidDecision,
          ImportCategory.plannedSessions,
          planned.id,
        );
        continue;
      }
      if (planned.audience != target.audience) {
        problems.add(
          ImportProblemCode.audienceMismatch,
          ImportCategory.plannedSessions,
          planned.id,
        );
        continue;
      }
      final season = seasons[target.season];
      if (season != null) {
        // Une saison close garde ses séances postérieures à la clôture : seul
        // le début de saison borne alors la date (règle de `BackupRules`).
        final inside = season.closed
            ? !planned.date.isBefore(season.start)
            : season.contains(planned.date);
        if (!inside) {
          problems.add(
            ImportProblemCode.outsideSeason,
            ImportCategory.plannedSessions,
            planned.id,
          );
          continue;
        }
      }
      writes.add(
        ImportWrite(
          category: ImportCategory.plannedSessions,
          id: planned.id,
          payload: planned.copyWith(groupId: target.group),
          group: target.group,
          season: target.season,
        ),
      );
    }
  }

  /// Écrit les saisies ; rend, par identifiant **du fichier**, le propriétaire
  /// et l'identifiant final de chaque saisie (un identifiant déterministe suit
  /// le groupe du club, jamais celui du fichier).
  Map<SessionId, ({SessionId id, GroupId group, SeasonId season})> _records() {
    final owner =
        <SessionId, ({SessionId id, GroupId group, SeasonId season})>{};
    final finalIds = <String>{};
    for (final record in snapshot.sessionRecords) {
      final r = resolved[record.groupId]!;
      var id = record.id;
      final sheet = record.sheetId;
      if (sheet != null && r.target != record.groupId) {
        try {
          if (id == sittingId(record.groupId, record.date, sheet)) {
            id = sittingId(r.target, record.date, sheet);
          }
        } on InvariantViolation {
          problems.add(
            ImportProblemCode.badIdentifier,
            ImportCategory.sessionRecords,
            record.id.value,
          );
          continue;
        }
      }
      if (!finalIds.add(id.value)) {
        problems.add(
          ImportProblemCode.duplicateId,
          ImportCategory.sessionRecords,
          id.value,
        );
        continue;
      }
      if (record.audience != r.audience) {
        problems.add(
          ImportProblemCode.audienceMismatch,
          ImportCategory.sessionRecords,
          record.id.value,
        );
        continue;
      }
      final season = seasons[r.season];
      if (season != null && !season.contains(record.date)) {
        problems.add(
          ImportProblemCode.outsideSeason,
          ImportCategory.sessionRecords,
          record.id.value,
        );
        continue;
      }
      owner[record.id] = (id: id, group: r.target, season: r.season);
      writes.add(
        ImportWrite(
          category: ImportCategory.sessionRecords,
          id: id.value,
          payload: record.copyWith(
            id: id,
            groupId: r.target,
            seasonId: r.season,
          ),
          group: r.target,
          season: r.season,
        ),
      );
    }
    return owner;
  }

  void _attempts(
    Map<SessionId, ({SessionId id, GroupId group, SeasonId season})> owners,
  ) {
    // `recordedAt` strictement croissant dans l'ordre du fichier (ADR 0024,
    // notes FB4c) : `createdAt` du serveur est exigé même du directeur, donc
    // égal dans un lot ; seul `recordedAt` fixe l'ordre à l'intérieur d'un lot.
    final base = input.now.toUtc();
    var index = 0;
    for (final attempt in snapshot.attempts) {
      final owner = owners[attempt.sessionId];
      final recordedAt = base.add(Duration(microseconds: index++));
      if (owner == null) continue;
      writes.add(
        ImportWrite(
          category: ImportCategory.attempts,
          id: attempt.id.value,
          payload: attempt.copyWith(sessionId: owner.id),
          group: owner.group,
          season: owner.season,
          student: attempt.studentId,
          recordedAt: recordedAt,
        ),
      );
    }
  }

  /// Le groupe qui possède un acquis, un bilan ou un acquittement : parmi les
  /// groupes de l'élève, pour un enseignant parmi **les siens** ; puis la
  /// saison ouverte, la plus récente, puis l'identifiant (comme
  /// `OwnerResolver.ofStudent`). Sans groupe : décision explicite.
  ({GroupId group, SeasonId season})? _ownerOf(StudentId student) {
    final candidates =
        <({GroupId group, SeasonId season, bool open, DateTime start})>[];
    for (final group in {...?_groupsOfStudent[student]}) {
      if (input.actor.isTeacher && !input.actor.groups.contains(group)) {
        continue;
      }
      final target = _target(group);
      if (target == null) continue;
      final season = seasons[target.season];
      candidates.add((
        group: group,
        season: target.season,
        open: !(season?.closed ?? false),
        start: season?.start ?? DateTime.fromMillisecondsSinceEpoch(0),
      ));
    }
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        if (a.open != b.open) return a.open ? -1 : 1;
        final byStart = b.start.compareTo(a.start);
        return byStart != 0 ? byStart : a.group.value.compareTo(b.group.value);
      });
      return (group: candidates.first.group, season: candidates.first.season);
    }
    switch (input.decisions.students[student]) {
      case null:
        if (!undecided.students.contains(student)) {
          undecided.students.add(student);
        }
        return null;
      case SkipIt():
        return null;
      case AttachTo(:final target):
        final resolvedTarget = _target(target);
        if (resolvedTarget == null) {
          problems.add(
            ImportProblemCode.invalidDecision,
            ImportCategory.students,
            student.value,
          );
          return null;
        }
        return (group: resolvedTarget.group, season: resolvedTarget.season);
    }
  }

  void _studentData() {
    final owners = <StudentId, ({GroupId group, SeasonId season})?>{};
    ({GroupId group, SeasonId season})? owner(StudentId id) =>
        owners.putIfAbsent(id, () => _ownerOf(id));
    bool skipped(StudentId id) =>
        input.decisions.students[id] is SkipIt &&
        (_groupsOfStudent[id] ?? const []).isEmpty;

    void add(
      ImportCategory category,
      String id,
      Object payload,
      StudentId student,
    ) {
      final o = owner(student);
      if (o == null) {
        if (skipped(student)) _ignore(category);
        return;
      }
      writes.add(
        ImportWrite(
          category: category,
          id: id,
          payload: payload,
          group: o.group,
          season: o.season,
          student: student,
        ),
      );
    }

    for (final a in snapshot.blockAcquisitions) {
      add(ImportCategory.acquisitions, a.id.value, a, a.studentId);
    }
    for (final a in snapshot.assessments) {
      add(ImportCategory.assessments, a.id.value, a, a.studentId);
    }
    for (final a
        in snapshot.alertAcknowledgements ?? const <AlertAcknowledgement>[]) {
      add(ImportCategory.acknowledgements, a.id.value, a, a.studentId);
    }
  }
}
