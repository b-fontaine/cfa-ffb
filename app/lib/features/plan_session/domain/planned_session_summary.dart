import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'planned_session_summary.freezed.dart';

/// Une séance planifiée telle que la planification la présente : la séance,
/// son groupe (s'il existe encore) et la saisie faite pour ce groupe le même
/// jour (ADR 0007, lien dérivé).
@freezed
abstract class PlannedSessionSummary with _$PlannedSessionSummary {
  const factory PlannedSessionSummary({
    required Session session,

    /// Groupe de la séance ; `null` sans groupe ou quand il a disparu.
    Group? group,

    /// Saisie de cette séance : même groupe, même jour, même séance du
    /// catalogue (`recordFor`, ADR 0016) ; `null` tant qu'il n'y en a pas
    /// (« Noter les résultats » reste proposé).
    SessionId? recordId,
  }) = _PlannedSessionSummary;

  const PlannedSessionSummary._();

  /// La séance visait un groupe que le club ne connaît plus.
  bool get groupUnavailable => session.groupId != null && group == null;
}
