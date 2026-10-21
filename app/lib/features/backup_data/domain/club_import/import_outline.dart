import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Un groupe du fichier, tel que l'écran de correspondance le présente : de
/// quoi le reconnaître (nom, public, saison, effectif), jamais un élève.
final class OutlineGroup {
  const OutlineGroup({
    required this.id,
    required this.name,
    required this.audience,
    required this.seasonLabel,
    required this.students,
  });

  final GroupId id;
  final String name;
  final Audience audience;
  final String? seasonLabel;

  /// Élèves distincts qui y ont été inscrits.
  final int students;
}

/// Une séance planifiée du fichier **sans groupe**.
final class OutlineSession {
  const OutlineSession({
    required this.id,
    required this.title,
    required this.date,
  });

  final String id;
  final String title;
  final DateTime date;
}

/// Un élève du fichier qui n'appartient à aucun groupe du fichier.
final class OutlineStudent {
  const OutlineStudent({required this.id, required this.firstName});

  final StudentId id;
  final String firstName;
}

/// Ce que l'écran d'import doit montrer du **fichier** pour que l'animateur
/// décide (FB7, partie B) : les groupes à associer, les séances et les élèves
/// sans groupe, et l'avancement d'un import déjà commencé. Dérivé du fichier
/// lu par `PrepareClubImport` ; le rapport (`ImportReport`) reste, lui, sans
/// aucun texte du fichier.
///
/// [marker] est le marqueur **complet** (empreinte du fichier, `planId`, rôle,
/// `restored`, `updatedAt`…) : l'écran n'en montre que des comptes (lots faits
/// sur lots prévus), jamais l'auteur du marqueur ni l'empreinte du fichier.
final class ImportOutline {
  const ImportOutline({
    this.groups = const [],
    this.looseSessions = const [],
    this.looseStudents = const [],
    this.marker,
  });

  factory ImportOutline.of(BackupSnapshot snapshot, {ImportMarker? marker}) {
    final seasons = {for (final s in snapshot.seasons) s.id: s.label};
    final inGroup = <StudentId>{
      for (final group in snapshot.groups)
        for (final membership in group.memberships) membership.studentId,
    };
    return ImportOutline(
      groups: [
        for (final group in snapshot.groups)
          OutlineGroup(
            id: group.id,
            name: group.name,
            audience: group.audience,
            seasonLabel: seasons[group.seasonId],
            students: {for (final m in group.memberships) m.studentId}.length,
          ),
      ],
      looseSessions: [
        for (final session in snapshot.plannedSessions)
          if (session.groupId == null)
            OutlineSession(
              id: session.id,
              title: session.title,
              date: session.date,
            ),
      ],
      looseStudents: [
        for (final student in snapshot.students)
          if (!inGroup.contains(student.id))
            OutlineStudent(id: student.id, firstName: student.firstName),
      ],
      marker: marker,
    );
  }

  static const empty = ImportOutline();

  final List<OutlineGroup> groups;
  final List<OutlineSession> looseSessions;
  final List<OutlineStudent> looseStudents;

  /// Le marqueur du fichier pour ce compte, s'il existe (import commencé).
  final ImportMarker? marker;
}
