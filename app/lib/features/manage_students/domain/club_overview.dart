import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'club_overview.freezed.dart';

/// Un élève et sa progression en un coup d'œil (liste des élèves).
@freezed
abstract class StudentSummary with _$StudentSummary {
  const factory StudentSummary({
    required Student student,
    required int validatedCount,
    required int exerciseCount,

    /// Exercices dont l'alerte d'échecs consécutifs est active (R4).
    required int alertCount,

    /// Aucun passage et rien d'acquis : « Parcours à commencer » plutôt qu'un
    /// « 0 sur 70 » (T7).
    @Default(false) bool toStart,
  }) = _StudentSummary;
}

/// Un groupe de la saison et ses membres à la date du jour.
@freezed
abstract class GroupOverview with _$GroupOverview {
  const factory GroupOverview({
    required Group group,
    required List<StudentSummary> members,
  }) = _GroupOverview;
}

/// Le club : groupes de la saison en cours et élèves sans groupe.
@freezed
abstract class ClubOverview with _$ClubOverview {
  const factory ClubOverview({
    required List<GroupOverview> groups,
    required List<StudentSummary> unassigned,
  }) = _ClubOverview;

  const ClubOverview._();

  /// Groupes proposables à l'ouverture ou à la suggestion d'une séance : ceux
  /// qui ont au moins un membre.
  List<GroupOverview> get eligibleGroups => [
    for (final group in groups)
      if (group.members.isNotEmpty) group,
  ];

  /// Nombre total d'exercices en alerte dans le club.
  int get alertCount => [
    for (final group in groups) ...group.members,
    ...unassigned,
  ].fold(0, (sum, student) => sum + student.alertCount);
}
