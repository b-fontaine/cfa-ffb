// Usage : dart run tool/import_plan_fixture.dart <dossier de sortie>
//
// Produit les ÉCRITURES du plan d'import (FB7) jouées par
// `scripts/rules_test/import.test.mjs` contre l'émulateur Firestore et les
// VRAIES règles : les mêmes documents que l'application écrit
// (`ClubImportOperations`), lot par lot, marqueur compris. Rien n'est écrit
// dans le dépôt : `scripts/rules_test.sh` appelle cet outil, puis le test Node
// lit le dossier (variable IMPORT_PLAN_DIR). Les fichiers de sauvegarde sont
// fictifs (`test/support/realistic_backup.dart`), aucune donnée réelle.
//
// Fichiers :
//   director.json      un club vide, le directeur (≥ 1500 écritures)
//   teacher.json       le groupe `g1` d'un enseignant, fiches neuves
//   teacher-large.json le même groupe, 30 fiches (budget de lectures)
//   teacher-scope.json les écritures d'un fichier construit pour un
//                      gestionnaire, réparties en « permises à l'enseignant »
//                      et « refusées » d'après le plan : les règles doivent
//                      suivre le plan
import 'dart:convert';
import 'dart:io';

import 'package:billard_cfa/app/club_import_operations.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';

import '../test/support/realistic_backup.dart';

/// L'identifiant du compte qui importe, remplacé par celui de l'acteur du test.
const importer = 'u-importer';

const paths = ClubPaths(ClubId('c1'));
final now = DateTime.utc(2026, 10, 12, 10);

Object? encode(Object? value) => switch (value) {
  null => null,
  ServerTimestamp() => {r'$serverTimestamp': true},
  ArrayUnion(:final values) => {r'$arrayUnion': values.map(encode).toList()},
  DateTime() => {r'$date': value.toUtc().toIso8601String()},
  List<Object?>() => value.map(encode).toList(),
  Map<String, Object?>() => {
    for (final entry in value.entries) entry.key: encode(entry.value),
  },
  _ => value,
};

Map<String, Object?> encodeOp(WriteOp op) => switch (op) {
  SetOp(:final path, :final fields, :final merge) => {
    'kind': merge ? 'merge' : 'set',
    'path': path,
    'fields': encode(fields),
  },
  UpdateOp(:final path, :final fields) => {
    'kind': 'update',
    'path': path,
    'fields': encode(fields),
  },
  DeleteOp(:final path) => {'kind': 'delete', 'path': path},
};

List<WriteOp> operationsOf(ImportWrite write, ClubInventory inventory) =>
    ClubImportOperations.of(paths, write, inventory, const UserId(importer));

/// Les lots d'un plan, au format du test Node.
Map<String, Object?> exportPlan(
  ClubImportPlan plan,
  ClubInventory inventory,
  Role role,
) => {
  'fileId': plan.fingerprint,
  'planId': plan.planId,
  'role': role.name,
  'importer': importer,
  'writes': plan.totalWrites,
  'status': plan.status.name,
  'unverifiable': plan.report.unverifiableStudents,
  'counts': {
    for (final entry in plan.report.counts.entries)
      entry.key.name: entry.value.writes,
  },
  'lots': [
    for (final lot in plan.lots)
      {
        'index': lot.index,
        'ops': [
          for (final write in lot.writes)
            for (final op in operationsOf(write, inventory)) encodeOp(op),
        ],
      },
  ],
  'lotCount': plan.lots.length,
};

ClubImportPlan planFor(
  RealisticBackup backup,
  ImportActor actor,
  ClubInventory inventory, {
  BackupSnapshot? snapshot,
  ImportDecisions? decisions,
}) {
  final file = snapshot ?? backup.snapshot;
  ClubImportPlan planWith(ImportDecisions decided) =>
      const ClubImportPlanner().plan(
        ClubImportInput(
          snapshot: file,
          fingerprint: sha256Hex(backup.content),
          version: 5,
          exportedAt: backup.exportedAt,
          actor: actor,
          inventory: inventory,
          decisions: decided,
          now: now,
        ),
      );
  final decided =
      decisions ??
      ImportDecisions(
        groups: {for (final g in file.groups) g.id: const CreateGroup()},
      );
  var plan = planWith(decided);
  // Un enseignant confirme les fiches qu'il ne peut pas vérifier : c'est
  // précisément ce que `import.test.mjs` met à l'épreuve des règles.
  if (plan.status == ImportStatus.needsConfirmation &&
      plan.report.unverifiableStudents > 0) {
    plan = planWith(
      decided.copyWith(unverifiedConfirmed: plan.report.unverifiableStudents),
    );
  }
  if (plan.status != ImportStatus.ready) {
    stderr.writeln('plan non prêt : ${plan.status} ${plan.report.problems}');
    exit(1);
  }
  return plan;
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage : dart run tool/import_plan_fixture.dart <dossier>');
    exit(2);
  }
  final out = Directory(args.single)..createSync(recursive: true);
  void write(String name, Object json) =>
      File('${out.path}/$name').writeAsStringSync(jsonEncode(json));

  // 1. Directeur : un club vide, un gros fichier (≥ 1500 écritures).
  final big = RealisticBackup(
    groups: 4,
    studentsPerGroup: 8,
    sessionsPerGroup: 14,
    history: true,
    dayStep: 2,
  );
  final directorPlan = planFor(
    big,
    const ImportActor(Role.director),
    ClubInventory.empty,
  );
  if (directorPlan.totalWrites < 1500) {
    stderr.writeln('fichier trop petit : ${directorPlan.totalWrites}');
    exit(1);
  }
  write(
    'director.json',
    exportPlan(directorPlan, ClubInventory.empty, Role.director),
  );

  // 2. Enseignant : le groupe `g1` existe (même identifiant que le fichier).
  final single = RealisticBackup(groups: 1, sessionsPerGroup: 4, history: true);
  const teacherInventory = ClubInventory(
    groups: {GroupId('g1'): InventoryGroup(SeasonId('se1'), Audience.children)},
  );
  final teacherPlan = planFor(
    single,
    const ImportActor(Role.teacher, {GroupId('g1')}),
    teacherInventory,
  );
  write(
    'teacher.json',
    exportPlan(teacherPlan, teacherInventory, Role.teacher),
  );

  // 2 bis. Un grand groupe : 30 fiches neuves d'un enseignant (deux lectures de
  // règles par fiche : le budget de 20 documents d'un lot s'applique).
  final large = RealisticBackup(
    groups: 1,
    studentsPerGroup: 30,
    attemptsPerStudentSession: 2,
    history: true,
  );
  final largePlan = planFor(
    large,
    const ImportActor(Role.teacher, {GroupId('g1')}),
    teacherInventory,
  );
  write(
    'teacher-large.json',
    exportPlan(largePlan, teacherInventory, Role.teacher),
  );

  // 3. Les droits d'un enseignant d'après le plan, jouées contre les règles.
  final scope = RealisticBackup(
    sessionsPerGroup: 2,
    attemptsPerStudentSession: 2,
    history: true,
  );
  final mixed = scope.snapshot.copyWith(
    groups: [
      for (final g in scope.snapshot.groups)
        if (g.id != scope.groupId(1))
          g
        else
          g.copyWith(
            memberships: [
              for (final m in g.memberships)
                if (m.studentId == scope.studentId(1, 2))
                  m.copyWith(to: DateTime(2026, 9, 30)) // fermée
                else if (m.studentId == scope.studentId(1, 3))
                  m.copyWith(
                    from: DateTime(2026, 9, 15),
                  ) // ≠ début d'historique
                else
                  m,
            ],
          ),
    ],
  );
  const bothGroups = ClubInventory(
    groups: {
      GroupId('g1'): InventoryGroup(SeasonId('se1'), Audience.children),
      GroupId('g2'): InventoryGroup(SeasonId('se1'), Audience.adults),
    },
  );
  const teacher = ImportActor(Role.teacher, {GroupId('g1')});
  final explained = const ClubImportPlanner().explain(
    ClubImportInput(
      snapshot: mixed,
      fingerprint: sha256Hex(scope.content),
      version: 5,
      exportedAt: scope.exportedAt,
      actor: const ImportActor(Role.director),
      inventory: bothGroups,
      now: now,
    ),
    analyzedFor: teacher,
  )!;
  final denied = {
    for (final entry in explained.denied.entries)
      for (final id in entry.value) '${entry.key.name}:$id',
  };
  final allowed = [
    for (final w in explained.writes)
      if (!denied.contains(w.key)) w,
  ];
  List<Map<String, Object?>> opsOf(Iterable<ImportWrite> writes) => [
    for (final w in writes)
      for (final op in operationsOf(w, bothGroups)) encodeOp(op),
  ];
  // Unités refusées : une fiche et ses appartenances, ou une écriture seule.
  final deniedWrites = [
    for (final w in explained.writes)
      if (denied.contains(w.key)) w,
  ];
  final units = <List<ImportWrite>>[];
  for (final w in deniedWrites) {
    if (w.category == ImportCategory.memberships) continue;
    units.add([
      w,
      if (w.category == ImportCategory.students)
        for (final m in deniedWrites)
          if (m.category == ImportCategory.memberships &&
              m.student == w.student)
            m,
    ]);
  }
  write('teacher-scope.json', {
    'importer': importer,
    'allowedBatches': [
      opsOf(allowed.where((w) => !w.category.needsStudentDocument)),
      opsOf(allowed.where((w) => w.category.needsStudentDocument)),
    ],
    'deniedUnits': [
      for (final unit in units)
        {'category': unit.first.category.name, 'ops': opsOf(unit)},
    ],
    'deniedCategories': {
      for (final entry in explained.denied.entries)
        entry.key.name: entry.value.length,
    },
  });
  stdout.writeln(
    'plans écrits dans ${out.path} : directeur ${directorPlan.totalWrites} '
    'écritures en ${directorPlan.lots.length} lots, enseignant '
    '${teacherPlan.totalWrites}, droits ${allowed.length} permises / '
    '${deniedWrites.length} refusées',
  );
}
