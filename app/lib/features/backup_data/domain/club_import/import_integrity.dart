import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';

/// Regroupe les problèmes par code et catégorie, avec les premiers
/// identifiants techniques (jamais un prénom ni une remarque).
final class ProblemCollector {
  final _entries =
      <(ImportProblemCode, ImportCategory?), ({int count, List<String> ids})>{};

  /// Combien d'identifiants d'exemple garder par problème.
  static const sampleSize = 3;

  void add(
    ImportProblemCode code,
    ImportCategory? category, [
    String? id,
    int count = 1,
  ]) {
    final key = (code, category);
    final current = _entries[key];
    final ids = [...?current?.ids];
    if (id != null && ids.length < sampleSize) ids.add(id);
    _entries[key] = (count: (current?.count ?? 0) + count, ids: ids);
  }

  /// Ajoute un problème déjà regroupé (compte et exemples conservés).
  void merge(ImportProblem problem) {
    final key = (problem.code, problem.category);
    final current = _entries[key];
    final ids = [...?current?.ids];
    for (final id in problem.sample) {
      if (ids.length < sampleSize) ids.add(id);
    }
    _entries[key] = (count: (current?.count ?? 0) + problem.count, ids: ids);
  }

  bool get isEmpty => _entries.isEmpty;

  List<ImportProblem> build() => [
    for (final entry in _entries.entries)
      ImportProblem(
        entry.key.$1,
        entry.key.$2,
        count: entry.value.count,
        sample: entry.value.ids,
      ),
  ];
}

/// Contrôle d'intégrité d'une sauvegarde **avant toute écriture** vers un club
/// synchronisé (FB7) : cohérence interne (doublons, références, passages
/// orphelins) et **bornes du domaine et des règles Firestore** (celles de
/// `field_limits.dart`, comparées au fichier de règles par un test).
///
/// Le décodeur a déjà vérifié la forme, les types et les invariants de chaque
/// entité ; ici on **recense tout** au lieu de s'arrêter au premier manquement,
/// pour que l'animateur voie l'ampleur du problème. Rien n'y lit ni n'écrit le
/// club.
final class ImportIntegrity {
  const ImportIntegrity();

  ProblemCollector check(BackupSnapshot snapshot) {
    final problems = ProblemCollector();
    _duplicates(snapshot, problems);
    _references(snapshot, problems);
    _bounds(snapshot, problems);
    return problems;
  }

  void _duplicates(BackupSnapshot snapshot, ProblemCollector problems) {
    void unique(ImportCategory category, Iterable<String> ids) {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) {
          problems.add(ImportProblemCode.duplicateId, category, id);
        }
      }
    }

    unique(ImportCategory.seasons, [
      for (final s in snapshot.seasons) s.id.value,
    ]);
    unique(ImportCategory.groups, [
      for (final g in snapshot.groups) g.id.value,
    ]);
    unique(ImportCategory.students, [
      for (final s in snapshot.students) s.id.value,
    ]);
    unique(ImportCategory.sessionRecords, [
      for (final s in snapshot.sessionRecords) s.id.value,
    ]);
    unique(ImportCategory.attempts, [
      for (final a in snapshot.attempts) a.id.value,
    ]);
    unique(ImportCategory.assessments, [
      for (final a in snapshot.assessments) a.id.value,
    ]);
    unique(ImportCategory.acquisitions, [
      for (final a in snapshot.blockAcquisitions) a.id.value,
    ]);
    unique(ImportCategory.acknowledgements, [
      for (final a
          in snapshot.alertAcknowledgements ?? const <AlertAcknowledgement>[])
        a.id.value,
    ]);
    unique(ImportCategory.plannedSessions, [
      for (final s in snapshot.plannedSessions) s.id,
    ]);
    unique(ImportCategory.seasonArchives, [
      for (final a in snapshot.seasonArchives) a.seasonId.value,
    ]);
    unique(ImportCategory.memberships, [
      for (final g in snapshot.groups)
        for (final m in g.memberships)
          '${g.id.value}_${m.studentId.value}_${m.from.toIso8601String()}',
    ]);
  }

  void _references(BackupSnapshot snapshot, ProblemCollector problems) {
    final seasons = {for (final s in snapshot.seasons) s.id};
    final students = {for (final s in snapshot.students) s.id};
    final groups = {for (final g in snapshot.groups) g.id: g};
    final records = {for (final r in snapshot.sessionRecords) r.id: r};
    void dangling(ImportCategory category, String id, {required bool ok}) {
      if (!ok) {
        problems.add(ImportProblemCode.danglingReference, category, id);
      }
    }

    for (final group in snapshot.groups) {
      dangling(
        ImportCategory.groups,
        group.id.value,
        ok: seasons.contains(group.seasonId),
      );
      for (final m in group.memberships) {
        dangling(
          ImportCategory.memberships,
          group.id.value,
          ok: students.contains(m.studentId),
        );
      }
    }
    for (final record in snapshot.sessionRecords) {
      final group = groups[record.groupId];
      dangling(
        ImportCategory.sessionRecords,
        record.id.value,
        ok:
            group != null &&
            seasons.contains(record.seasonId) &&
            group.seasonId == record.seasonId &&
            record.present.every(students.contains),
      );
    }
    for (final attempt in snapshot.attempts) {
      final record = records[attempt.sessionId];
      if (record == null) {
        problems.add(
          ImportProblemCode.orphanAttempt,
          ImportCategory.attempts,
          attempt.id.value,
        );
        continue;
      }
      dangling(
        ImportCategory.attempts,
        attempt.id.value,
        ok:
            students.contains(attempt.studentId) &&
            record.present.contains(attempt.studentId),
      );
    }
    for (final a in snapshot.assessments) {
      dangling(
        ImportCategory.assessments,
        a.id.value,
        ok: students.contains(a.studentId),
      );
    }
    for (final a in snapshot.blockAcquisitions) {
      dangling(
        ImportCategory.acquisitions,
        a.id.value,
        ok: students.contains(a.studentId),
      );
    }
    for (final a
        in snapshot.alertAcknowledgements ?? const <AlertAcknowledgement>[]) {
      dangling(
        ImportCategory.acknowledgements,
        a.id.value,
        ok: students.contains(a.studentId),
      );
    }
    for (final planned in snapshot.plannedSessions) {
      final groupId = planned.groupId;
      dangling(
        ImportCategory.plannedSessions,
        planned.id,
        ok: groupId == null || groups.containsKey(groupId),
      );
    }
    final closed = {
      for (final s in snapshot.seasons)
        if (s.isClosed) s.id,
    };
    for (final archive in snapshot.seasonArchives) {
      dangling(
        ImportCategory.seasonArchives,
        archive.seasonId.value,
        ok: closed.contains(archive.seasonId),
      );
    }
  }

  void _bounds(BackupSnapshot snapshot, ProblemCollector problems) {
    void docId(ImportCategory category, String id) {
      if (!isDocumentId(id)) {
        problems.add(ImportProblemCode.badIdentifier, category, id);
      }
    }

    void reference(ImportCategory category, String owner, String? value) {
      if (value != null && !isReference(value)) {
        problems.add(ImportProblemCode.badIdentifier, category, owner);
      }
    }

    void date(ImportCategory category, String owner, DateTime? value) {
      if (value != null && !isoDateText.hasMatch(value.toIso8601String())) {
        problems.add(ImportProblemCode.badDate, category, owner);
      }
    }

    // Libellé de saison, prénom et historique de public sont bornés par les
    // invariants du domaine (`Season`, `Student`) : un fichier qui les dépasse
    // ne se décode pas, ils n'ont pas de contrôle ici.
    for (final s in snapshot.seasons) {
      docId(ImportCategory.seasons, s.id.value);
      date(ImportCategory.seasons, s.id.value, s.startDate);
      date(ImportCategory.seasons, s.id.value, s.endDate);
      date(ImportCategory.seasons, s.id.value, s.closedOn);
    }
    for (final g in snapshot.groups) {
      docId(ImportCategory.groups, g.id.value);
      // Les identifiants de groupe ne contiennent jamais `_` : les règles s'en
      // servent pour reconnaître le groupe d'un identifiant de saisie.
      if (g.id.value.contains('_')) {
        problems.add(
          ImportProblemCode.badIdentifier,
          ImportCategory.groups,
          g.id.value,
        );
      }
      reference(ImportCategory.groups, g.id.value, g.seasonId.value);
      if (g.name.runes.length > maxGroupNameLength) {
        problems.add(
          ImportProblemCode.valueTooLong,
          ImportCategory.groups,
          g.id.value,
        );
      }
      for (final m in g.memberships) {
        date(ImportCategory.memberships, g.id.value, m.from);
        date(ImportCategory.memberships, g.id.value, m.to);
        reference(ImportCategory.memberships, g.id.value, m.studentId.value);
      }
    }
    for (final s in snapshot.students) {
      docId(ImportCategory.students, s.id.value);
      for (final change in s.audienceHistory) {
        date(ImportCategory.students, s.id.value, change.effectiveFrom);
      }
    }
    for (final p in snapshot.plannedSessions) {
      docId(ImportCategory.plannedSessions, p.id);
      reference(ImportCategory.plannedSessions, p.id, p.groupId?.value);
      reference(ImportCategory.plannedSessions, p.id, p.sheetId?.value);
      date(ImportCategory.plannedSessions, p.id, p.date);
      if (p.title.runes.length > maxSessionTitleLength) {
        problems.add(
          ImportProblemCode.valueTooLong,
          ImportCategory.plannedSessions,
          p.id,
        );
      }
    }
    for (final r in snapshot.sessionRecords) {
      docId(ImportCategory.sessionRecords, r.id.value);
      if (r.id.value.length > maxSessionReferenceLength) {
        problems.add(
          ImportProblemCode.badIdentifier,
          ImportCategory.sessionRecords,
          r.id.value,
        );
      }
      reference(ImportCategory.sessionRecords, r.id.value, r.groupId.value);
      reference(ImportCategory.sessionRecords, r.id.value, r.seasonId.value);
      reference(ImportCategory.sessionRecords, r.id.value, r.mainBlockId);
      reference(ImportCategory.sessionRecords, r.id.value, r.recallBlockId);
      reference(ImportCategory.sessionRecords, r.id.value, r.sheetId?.value);
      date(ImportCategory.sessionRecords, r.id.value, r.date);
      if (r.present.length > maxPresentStudents) {
        problems.add(
          ImportProblemCode.tooManyPresent,
          ImportCategory.sessionRecords,
          r.id.value,
        );
      }
      for (final id in r.present) {
        reference(ImportCategory.sessionRecords, r.id.value, id.value);
      }
    }
    for (final a in snapshot.attempts) {
      docId(ImportCategory.attempts, a.id.value);
      reference(ImportCategory.attempts, a.id.value, a.sessionId.value);
      reference(ImportCategory.attempts, a.id.value, a.studentId.value);
      reference(ImportCategory.attempts, a.id.value, a.exercise.blockId);
      date(ImportCategory.attempts, a.id.value, a.date);
      if (a.exercise.number > maxExerciseNumber) {
        problems.add(
          ImportProblemCode.valueOutOfRange,
          ImportCategory.attempts,
          a.id.value,
        );
      }
    }
    for (final a in snapshot.assessments) {
      docId(ImportCategory.assessments, a.id.value);
      date(ImportCategory.assessments, a.id.value, a.date);
      reference(ImportCategory.assessments, a.id.value, a.studentId.value);
    }
    for (final a in snapshot.blockAcquisitions) {
      docId(ImportCategory.acquisitions, a.id.value);
      date(ImportCategory.acquisitions, a.id.value, a.date);
      reference(ImportCategory.acquisitions, a.id.value, a.studentId.value);
      reference(ImportCategory.acquisitions, a.id.value, a.blockId);
    }
    for (final a
        in snapshot.alertAcknowledgements ?? const <AlertAcknowledgement>[]) {
      docId(ImportCategory.acknowledgements, a.id.value);
      date(ImportCategory.acknowledgements, a.id.value, a.date);
      reference(ImportCategory.acknowledgements, a.id.value, a.studentId.value);
      reference(
        ImportCategory.acknowledgements,
        a.id.value,
        a.lastAttemptId.value,
      );
      reference(
        ImportCategory.acknowledgements,
        a.id.value,
        a.exercise.blockId,
      );
      if (a.exercise.number > maxExerciseNumber) {
        problems.add(
          ImportProblemCode.valueOutOfRange,
          ImportCategory.acknowledgements,
          a.id.value,
        );
      }
    }
    for (final a in snapshot.seasonArchives) {
      reference(
        ImportCategory.seasonArchives,
        a.seasonId.value,
        a.seasonId.value,
      );
      for (final line in a.exercises) {
        reference(
          ImportCategory.seasonArchives,
          a.seasonId.value,
          line.exercise.blockId,
        );
        if (line.exercise.number > maxExerciseNumber) {
          problems.add(
            ImportProblemCode.valueOutOfRange,
            ImportCategory.seasonArchives,
            a.seasonId.value,
          );
        }
      }
    }
  }

  /// Un identifiant de document Firestore acceptable pour les règles : non
  /// vide, au plus [maxIdentifierLength] caractères, sans `/`, ni `.` ni `..`,
  /// ni la forme réservée `__x__`.
  static bool isDocumentId(String id) =>
      id.isNotEmpty &&
      id.runes.length <= maxIdentifierLength &&
      !id.contains('/') &&
      id != '.' &&
      id != '..' &&
      !(id.startsWith('__') && id.endsWith('__'));

  /// Une référence (champ d'un document) : non vide, au plus
  /// [maxIdentifierLength] caractères.
  static bool isReference(String value) =>
      value.isNotEmpty && value.runes.length <= maxIdentifierLength;
}
