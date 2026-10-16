import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'closure_proposal.freezed.dart';

/// Ce que l'animateur fait d'un élève à la clôture de la saison.
enum ClosureChoice { keep, erase }

/// Pourquoi la règle propose ce choix (écrit sur la ligne de l'élève).
enum ClosureReason {
  /// Absent de toute séance de la saison.
  inactive,

  /// Inscrit avant la saison : conservation limitée à la saison suivante.
  retentionExpired,

  /// Actif et inscrit cette saison : reconduit.
  carriedOver,
}

/// Une ligne de l'assistant de clôture : un élève, le choix proposé et son
/// motif. L'animateur peut tout inverser ; la règle propose, elle ne décide
/// pas.
@freezed
abstract class ClosureProposal with _$ClosureProposal {
  const factory ClosureProposal({
    required StudentId studentId,
    required String firstName,
    required Audience audience,
    required ClosureChoice choice,
    required ClosureReason reason,
  }) = _ClosureProposal;
}
