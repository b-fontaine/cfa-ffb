import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';

/// L'effacement d'**un** élève dans un club synchronisé, par lots reprenables
/// (ADR 0024, décision 19 ; FB8 partie A). Le droit à l'effacement est honoré à
/// tout moment, quelle que soit la taille du dossier :
///
/// 1. **Marquer** : la fiche passe à `erasing` (marqueur transitoire, aucun
///    prénom de plus). Les règles refusent alors toute **création** de
///    donnée liée à la fiche (passages, blocs acquis, bilans, acquittements)
///    et un appareil retardataire ne la ressuscite pas ; une **édition**
///    tardive reste acceptée, puis supprimée par la purge ou l'étape 3
///    (limite assumée).
/// 2. **Purger** par lots : accès des comptes parent et élève coupé d'abord,
///    puis passages, blocs acquis, bilans, acquittements, appartenances, et
///    identifiant retiré des listes de présents (`arrayRemove`). Les étiquettes
///    de séance, non nominatives, restent (ADR 0023).
/// 3. **Supprimer la fiche, en dernier**, avec le marqueur d'opération :
///    aucune trace de l'effacement ne reste (pas de tombstone). Cette étape
///    **rejoue d'abord la purge** : une présence qu'un appareil retardataire a
///    ajoutée depuis (les règles ne parcourent pas une liste) est retirée
///    juste avant la suppression de la fiche, ce qui réduit la fenêtre sans la
///    fermer.
///
/// Reprise : chaque étape recalcule ce qui reste d'après l'état du club ;
/// rejouer, interrompre ou lancer sur deux appareils converge.
final class StudentErasureOperation implements ResumableOperation {
  StudentErasureOperation(this._purge, this.studentId, ClubId club)
    : key = operationKey(OperationKind.erasure, studentId.value, club: club);

  final StudentPurge _purge;
  final StudentId studentId;

  @override
  final String key;

  @override
  OperationKind get kind => OperationKind.erasure;

  @override
  ClosureTerms? get terms => null;

  @override
  Future<bool> isAlreadyDone() async => !await _purge.exists(studentId);

  @override
  late final List<OperationStage> stages = [
    _Flag(_purge, studentId),
    _Purge(_purge, studentId),
    _Remove(_purge, studentId),
  ];
}

final class _Flag implements OperationStage {
  const _Flag(this._purge, this._id);

  final StudentPurge _purge;
  final StudentId _id;

  @override
  Future<List<OperationLot>> remaining(int maxWrites) async {
    if (!await _purge.exists(_id)) return const [];
    if ((await _purge.flagged()).contains(_id)) return const [];
    return [
      _purge.flag({_id}),
    ];
  }
}

final class _Purge implements OperationStage {
  const _Purge(this._purge, this._id);

  final StudentPurge _purge;
  final StudentId _id;

  @override
  Future<List<OperationLot>> remaining(int maxWrites) =>
      _purge.purgeLots({_id}, maxWrites: maxWrites);
}

final class _Remove implements OperationStage {
  const _Remove(this._purge, this._id);

  final StudentPurge _purge;
  final StudentId _id;

  @override
  Future<List<OperationLot>> remaining(int maxWrites) async {
    // La fiche a disparu (une clôture a absorbé cet effacement, ou un autre
    // appareil l'a terminé) : il ne reste que le marqueur à retirer.
    if (!await _purge.exists(_id)) return const [];
    return [
      ...await _purge.purgeLots({_id}, maxWrites: maxWrites),
      _purge.removeRecords({_id}),
    ];
  }
}
