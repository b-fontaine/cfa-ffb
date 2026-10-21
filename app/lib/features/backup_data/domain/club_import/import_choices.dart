import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Un groupe du club où rattacher une séance ou un élève sans groupe, **tel
/// qu'il sera après l'import** (créé, associé, ou déjà là).
final class ImportDestination {
  const ImportDestination(this.id, this.name);

  final GroupId id;
  final String name;
}

/// Un groupe du club sur lequel plusieurs groupes du fichier sont associés :
/// la fusion demande une confirmation.
final class ImportMerge {
  const ImportMerge(this.target, this.name);

  final GroupId target;
  final String name;
}

/// Ce que l'animateur a à décider à cette étape, **déjà dérivé** du plan, des
/// décisions et des groupes du club : l'écran n'affiche que ces listes.
final class ImportChoices {
  const ImportChoices({
    this.groups = const [],
    this.merges = const [],
    this.destinations = const [],
    this.sessions = const [],
    this.students = const [],
    this.targets = const [],
  });

  factory ImportChoices.of({
    required ClubImportPlan plan,
    required ImportDecisions decisions,
    required List<ImportTarget> targets,
  }) {
    final outline = plan.outline;
    final report = plan.report;
    final undecided = {...report.undecidedGroups};
    final names = {for (final t in targets) t.id: t.name};

    // Les groupes à décider, ceux déjà décidés pendant l'étape, et tous quand
    // un import est commencé (l'animateur refait les mêmes choix).
    final groups = [
      for (final g in outline.groups)
        if (undecided.contains(g.id) ||
            decisions.groups.containsKey(g.id) ||
            outline.marker != null)
          g,
    ];

    final byTarget = <GroupId, int>{};
    decisions.groups.forEach((_, choice) {
      if (choice case UseExistingGroup(:final target)) {
        byTarget[target] = (byTarget[target] ?? 0) + 1;
      }
    });
    final merges = [
      for (final entry in byTarget.entries)
        if (entry.value > 1) ImportMerge(entry.key, names[entry.key] ?? ''),
    ];

    final destinations = <ImportDestination>[];
    for (final group in outline.groups) {
      final GroupId? id;
      final String name;
      switch (decisions.groups[group.id]) {
        case CreateGroup():
          id = group.id;
          name = group.name;
        case UseExistingGroup(:final target):
          id = target;
          name = names[target] ?? group.name;
        case null:
          id = undecided.contains(group.id) ? null : group.id;
          name = group.name;
      }
      if (id != null) destinations.add(ImportDestination(id, name));
    }

    final sessionIds = {
      ...report.undecidedSessions,
      ...decisions.plannedSessions.keys,
    };
    final studentIds = {
      ...report.undecidedStudents,
      ...decisions.students.keys,
    };
    return ImportChoices(
      groups: groups,
      merges: merges,
      destinations: destinations,
      sessions: [
        for (final s in outline.looseSessions)
          if (sessionIds.contains(s.id)) s,
      ],
      students: [
        for (final s in outline.looseStudents)
          if (studentIds.contains(s.id)) s,
      ],
      targets: targets,
    );
  }

  static const empty = ImportChoices();

  /// Les groupes du fichier à afficher.
  final List<OutlineGroup> groups;
  final List<ImportMerge> merges;
  final List<ImportDestination> destinations;
  final List<OutlineSession> sessions;
  final List<OutlineStudent> students;
  final List<ImportTarget> targets;

  /// Les groupes du club où [group] du fichier peut être associé.
  List<ImportTarget> targetsFor(OutlineGroup group) => [
    for (final t in targets)
      if (t.fits(group)) t,
  ];
}
