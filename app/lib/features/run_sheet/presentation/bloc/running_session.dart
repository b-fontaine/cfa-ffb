import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'running_session.freezed.dart';

/// Une séance guidée commencée, vue de l'accueil : où elle en est et d'où
/// elle vient (lecture seule, dérivée de l'état du guide).
@freezed
abstract class RunningSession with _$RunningSession {
  const factory RunningSession({
    /// Clé du guide : sert à le rouvrir ou à l'abandonner.
    required RunKey key,

    /// Étape courante (à partir de 0) et nombre d'étapes.
    required int step,
    required int stepCount,

    /// Phase de l'étape courante.
    required SessionPhase phase,

    /// Titre de la technique de la séance, partie `part` sur `partCount`.
    required String sheetTitle,
    required int part,
    required int partCount,

    /// Groupe et date de la séance planifiée d'où le guide a été lancé.
    GroupId? plannedGroupId,
    DateTime? plannedDate,
  }) = _RunningSession;
}
