import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'operation_marker.freezed.dart';

/// La nature d'une opération reprenable d'un club (ADR 0024, décision 19,
/// notes FB8a).
enum OperationKind {
  /// Effacement d'un élève et de tout ce qui s'y rapporte.
  erasure,

  /// Clôture d'une saison.
  closure;

  static OperationKind? tryParse(String? raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

/// Ce qu'une clôture a décidé au départ et que sa reprise doit retrouver
/// **sans** le demander de nouveau : une saison, un jour, deux choix. Aucune
/// donnée personnelle (les élèves à effacer sont repérés par `erasing` sur leur
/// fiche, jamais listés dans le marqueur).
@freezed
abstract class ClosureTerms with _$ClosureTerms {
  const factory ClosureTerms({
    required SeasonId seasonId,
    required DateTime closedOn,
    required bool prepareNext,
    required bool dropPlanned,
  }) = _ClosureTerms;
}

/// L'avancement d'une opération, **sans aucune donnée personnelle** : un
/// identifiant d'opération (empreinte, voir [operationKey]), sa nature,
/// l'avancement (lots écrits, étape en cours), le rôle et le compte de son
/// auteur, deux dates du serveur. Un marqueur est **propre à son auteur** (son
/// identifiant en porte l'`uid`) : personne ne crée, ne lit pour agir ni
/// n'avance celui d'un autre, et un enseignant ne peut en poser aucun.
///
/// Il existe **tant que l'opération est en cours** : le dernier lot le
/// supprime avec ce qu'il achève (la fiche d'un élève effacé, la clôture) ;
/// aucune trace de l'opération ne reste.
final class OperationMarker {
  const OperationMarker({
    required this.key,
    required this.kind,
    required this.done,
    required this.stage,
    required this.role,
    this.terms,
    this.updatedAt,
  });

  /// Empreinte de l'opération (voir [operationKey]).
  final String key;
  final OperationKind kind;

  /// Lots déjà écrits (marqueur compris), reprises comprises.
  final int done;

  /// L'étape en cours : les étapes d'indice inférieur sont terminées.
  final int stage;
  final Role role;

  /// Les termes de la clôture (nature `closure` seulement).
  final ClosureTerms? terms;
  final DateTime? updatedAt;

  /// Le marqueur après un lot de plus, qui laisse l'étape [nextStage].
  OperationMarker advanced({required int nextStage}) => OperationMarker(
    key: key,
    kind: kind,
    done: done + 1,
    stage: nextStage,
    role: role,
    terms: terms,
  );
}

/// L'identifiant d'une opération : l'empreinte SHA-256 de sa nature et de sa
/// cible, **salée par l'identifiant du club** quand [club] est donné
/// (`sha256(club|nature|cible)`). Sans sel, quiconque connaît l'identifiant de
/// l'élève (une sauvegarde exportée) recalculerait l'empreinte : ce serait un
/// pseudonyme. Salée, elle ne se recalcule qu'avec l'identifiant du club, que
/// tout appareil du club connaît : la reprise par un second appareil du même
/// auteur retrouve son marqueur. Elle ne nomme personne et reste déterministe.
/// Un identifiant de club ne contient pas `|` (`[A-Za-z0-9_-]`).
String operationKey(OperationKind kind, String target, {ClubId? club}) =>
    sha256Hex(
      club == null
          ? '${kind.name}:$target'
          : '${club.value}|${kind.name}|$target',
    );

/// Un identifiant **déterministe** dérivé de l'opération : la reprise d'une
/// clôture retrouve le même identifiant pour la saison ou le groupe qu'elle
/// crée, au lieu d'en créer un second si le premier lot est déjà passé.
/// Forme d'un UUID (aucun `_`, 36 caractères).
String derivedId(String operationKey, String label) {
  final hex = sha256Hex('$operationKey|$label');
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
