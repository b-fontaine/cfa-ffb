import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';

/// Appartenance d'un élève à un groupe, de [from] à [to] (ouverte si `null`).
@freezed
abstract class Membership with _$Membership {
  const factory Membership({
    required StudentId studentId,
    required DateTime from,
    DateTime? to,
  }) = _Membership;
}

/// Un groupe de la saison, associé à un public (donc à une durée de séance).
@freezed
abstract class Group with _$Group {
  factory Group({
    required GroupId id,
    required SeasonId seasonId,
    required String name,
    required Audience audience,
    @Default([]) List<Membership> memberships,
  }) = _Group;

  Group._() {
    if (name.trim().isEmpty) {
      throw const InvariantViolation(InvariantCode.blankName);
    }
    if (!memberships.every((m) => m.to == null || !m.to!.isBefore(m.from))) {
      throw const InvariantViolation(InvariantCode.membershipPeriodInvalid);
    }
    final open = [
      for (final m in memberships)
        if (m.to == null) m.studentId,
    ];
    if (open.toSet().length != open.length) {
      throw const InvariantViolation(InvariantCode.membershipAlreadyOpen);
    }
  }

  /// Vrai si l'élève est membre à la date [date] (bornes incluses).
  bool isMemberOn(StudentId studentId, DateTime date) => memberships.any(
    (m) =>
        m.studentId == studentId &&
        !date.isBefore(m.from) &&
        (m.to == null || !date.isAfter(m.to!)),
  );

  /// Admet un élève dont le public à la date [from] est [studentAudience].
  ///
  /// Le public de l'élève doit être celui du groupe : passer un jeune en cours
  /// adultes = clore l'appartenance enfants et en ouvrir une dans un groupe
  /// adultes.
  Group admit({
    required StudentId studentId,
    required Audience studentAudience,
    required DateTime from,
  }) {
    if (studentAudience != audience) {
      throw const InvariantViolation(InvariantCode.audienceMismatch);
    }
    return Group(
      id: id,
      seasonId: seasonId,
      name: name,
      audience: audience,
      memberships: [
        ...memberships,
        Membership(studentId: studentId, from: from),
      ],
    );
  }

  /// Clôt l'appartenance ouverte de l'élève à la date [to].
  Group release({required StudentId studentId, required DateTime to}) {
    final open = memberships.indexWhere(
      (m) => m.studentId == studentId && m.to == null,
    );
    if (open < 0) {
      throw const InvariantViolation(InvariantCode.membershipNotOpen);
    }
    return Group(
      id: id,
      seasonId: seasonId,
      name: name,
      audience: audience,
      memberships: [
        for (var i = 0; i < memberships.length; i++)
          if (i == open) memberships[i].copyWith(to: to) else memberships[i],
      ],
    );
  }
}
