import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/spent_invitations.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/close_season/domain/build_archive.dart';
import 'package:billard_cfa/features/close_season/domain/next_season_plan.dart';
import 'package:billard_cfa/features/close_season/domain/planned_after_closure.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';

/// Les dépôts dont la clôture a besoin.
final class ClosureRepositories {
  const ClosureRepositories({
    required this.seasons,
    required this.groups,
    required this.students,
    required this.sessionRecords,
    required this.attempts,
    required this.plannedSessions,
    required this.archives,
  });

  final SeasonRepository seasons;
  final GroupRepository groups;
  final StudentRepository students;
  final SessionRecordRepository sessionRecords;
  final AttemptRepository attempts;
  final SessionRepository plannedSessions;
  final SeasonArchiveRepository archives;
}

/// La clôture d'une saison (ADR 0019) en **opération reprenable** (ADR 0024,
/// décision 19 ; FB8 partie A) : même résultat qu'`CloseSeason` en une seule
/// unité de travail, mais en lots de 400 écritures au plus, sur un club de
/// n'importe quelle taille.
///
/// Les étapes, dans l'ordre (chacune recalcule son travail d'après l'état du
/// club ; une étape faite ne laisse rien à refaire) :
///
/// 0. **Déclarer** : les élèves à effacer sont marqués `erasing` (aucune
///    donnée nouvelle ne s'y rapporte plus). C'est avec le marqueur d'opération
///    la **seule** mémoire du choix de l'animateur : la liste des élèves
///    n'est écrite nulle part ailleurs.
/// 1. **Archive** : l'archive agrégée est calculée sur les données complètes
///    et écrite **avant tout effacement** ; elle n'est jamais recalculée une
///    fois la saison close.
/// 2. **Séances planifiées** postérieures au jour de clôture supprimées (si
///    demandé), tant que la saison garde ses dates d'origine.
/// 3. **Clôture** de la saison (`closedOn`, fin de saison ramenée au jour).
/// 4. **Purge** des élèves marqués : toutes leurs données, hors leur fiche.
/// 5. **Reconduction** : saison suivante, groupes homonymes, élèves non
///    effacés (identifiants dérivés de l'opération : la reprise retrouve les
///    mêmes).
/// 6. **Invitations** utilisées ou échues du club supprimées (ADR 0025,
///    décision 6 ; FB8 partie B), celles que le compte peut lister : toutes
///    pour l'administrateur, jamais celles de directeur pour le directeur
///    ([SpentInvitations]). Une invitation encore valable reste.
/// 7. **Fin** : la purge est **rejouée** (une présence ajoutée depuis par un
///    appareil retardataire est retirée), puis les fiches des élèves effacés
///    sont supprimées **en dernier**, avec le marqueur.
///
/// **Effacements en cours** : la purge et la fin portent sur **toutes** les
/// fiches `erasing` du club, pas seulement sur celles que cette clôture a
/// déclarées (la reprise ne peut pas les distinguer, la liste des élèves
/// n'étant écrite nulle part). Un effacement individuel commencé par un autre
/// auteur est donc **terminé** par la clôture ; son marqueur, qui ne contient
/// qu'une empreinte, se retire à la prochaine reprise de cet auteur (voir
/// `ClubStudentErasure`). L'archive agrégée compte ces élèves comme ils sont :
/// ce qui reste de leurs données au moment du calcul (ADR 0019, 0024, 0025).
///
/// Deux clôtures simultanées convergent (marqueurs par auteur, écritures
/// idempotentes, archive non recalculée après la clôture de la saison).
final class SeasonClosureOperation implements ResumableOperation {
  SeasonClosureOperation({
    required this.repositories,
    required this.purge,
    required this.closureTerms,
    required this.invitations,
    this.erase = const {},
  }) : key = operationKey(OperationKind.closure, closureTerms.seasonId.value);

  final ClosureRepositories repositories;
  final StudentPurge purge;
  final ClosureTerms closureTerms;
  final SpentInvitations invitations;

  /// Les élèves à effacer, **au premier lancement seulement** : une reprise les
  /// retrouve par leur marque `erasing`.
  final Set<StudentId> erase;

  /// Les compteurs de **cette** exécution (le compte rendu d'une clôture menée
  /// sans interruption).
  int groupsPrepared = 0;
  int plannedDropped = 0;

  @override
  final String key;

  @override
  OperationKind get kind => OperationKind.closure;

  @override
  ClosureTerms get terms => closureTerms;

  SeasonId get _seasonId => closureTerms.seasonId;

  @override
  Future<bool> isAlreadyDone() async {
    final season = await repositories.seasons.byId(_seasonId);
    return season != null && season.isClosed;
  }

  @override
  late final List<OperationStage> stages = [
    _Stage(_declare),
    _Stage(_archive),
    _Stage(_dropPlanned),
    _Stage(_close),
    _Stage(_purge),
    _Stage(_prepareNext),
    _Stage(_purgeInvitations),
    _Stage(_finish),
  ];

  /// Découpe [items] en lots de [max] écritures au plus ; chaque lot applique
  /// ses éléments dans l'ordre.
  static List<OperationLot> _pack(
    List<({int cost, Future<void> Function() apply})> items,
    int max,
  ) {
    final lots = <OperationLot>[];
    var batch = <({int cost, Future<void> Function() apply})>[];
    var cost = 0;
    void flush() {
      if (batch.isEmpty) return;
      final applied = batch;
      lots.add(
        OperationLot(
          writes: cost,
          apply: () async {
            for (final item in applied) {
              await item.apply();
            }
          },
        ),
      );
      batch = [];
      cost = 0;
    }

    for (final item in items) {
      if (cost > 0 && cost + item.cost > max) flush();
      batch.add(item);
      cost += item.cost;
    }
    flush();
    return lots;
  }

  Future<List<OperationLot>> _declare(int max) async {
    if (erase.isEmpty) return const [];
    final flagged = await purge.flagged();
    final existing = {
      for (final student in await repositories.students.all()) student.id,
    };
    final missing = [
      for (final id in erase)
        if (!flagged.contains(id) && existing.contains(id)) id,
    ];
    return [
      for (var i = 0; i < missing.length; i += max)
        purge.flag(
          missing
              .sublist(i, i + max > missing.length ? missing.length : i + max)
              .toSet(),
        ),
    ];
  }

  Future<List<OperationLot>> _archive(int max) async {
    final season = await repositories.seasons.byId(_seasonId);
    // Une saison close a déjà son archive : jamais recalculée sur des données
    // en partie effacées.
    if (season == null || season.isClosed) return const [];
    final archive = buildArchive(
      season: season,
      groups: await repositories.groups.all(),
      sessions: await repositories.sessionRecords.all(),
      attempts: await repositories.attempts.all(),
    );
    final docs = archive.audiences.length + archive.exercises.length;
    return [
      OperationLot(
        // Les documents d'une archive précédente (reprise) sont remplacés.
        writes: docs * 2,
        apply: () => repositories.archives.save(archive),
      ),
    ];
  }

  Future<List<OperationLot>> _dropPlanned(int max) async {
    if (!closureTerms.dropPlanned) return const [];
    final season = await repositories.seasons.byId(_seasonId);
    if (season == null || season.isClosed) return const [];
    final groups = await repositories.groups.all();
    final dropped = plannedAfterClosure(
      season: season,
      groupIds: {
        for (final group in groups)
          if (group.seasonId == _seasonId) group.id,
      },
      planned: await repositories.plannedSessions.getAll(),
      day: closureTerms.closedOn,
    );
    plannedDropped = dropped.length;
    return _pack([
      for (final planned in dropped)
        (cost: 1, apply: () => repositories.plannedSessions.delete(planned.id)),
    ], max);
  }

  Future<List<OperationLot>> _close(int max) async {
    final season = await repositories.seasons.byId(_seasonId);
    if (season == null || season.isClosed) return const [];
    final day = closureTerms.closedOn.dateOnly;
    final closed = season.copyWith(
      closedOn: day,
      endDate: day.isBefore(season.endDate) ? day : season.endDate,
    );
    return [
      OperationLot(writes: 1, apply: () => repositories.seasons.save(closed)),
    ];
  }

  Future<List<OperationLot>> _purge(int max) async {
    final flagged = await purge.flagged();
    return await purge.purgeLots(flagged, maxWrites: max);
  }

  Future<List<OperationLot>> _prepareNext(int max) async {
    if (!closureTerms.prepareNext) return const [];
    final closed = await repositories.seasons.byId(_seasonId);
    if (closed == null || !closed.isClosed) return const [];
    final groups = await repositories.groups.all();
    // Deux écritures par élève reconduit et par phase (appartenance, liste de
    // groupes de la fiche) et une par groupe : une étape tient dans un lot.
    final chunk = ((max - 2) ~/ 2).clamp(1, max);
    final plan = planNextSeason(
      closed: closed,
      day: closureTerms.closedOn,
      seasons: await repositories.seasons.all(),
      groups: groups,
      erased: await purge.flagged(),
      newSeasonId: SeasonId(derivedId(key, 'season')),
      newGroupId: (origin) =>
          GroupId(derivedId(key, 'group:${origin.id.value}')),
      chunk: chunk,
    );
    if (plan == null) return const [];
    groupsPrepared = groups.where((g) => g.seasonId == _seasonId).length;
    // Phase 1 : la saison suivante et les groupes de destination avec leurs
    // élèves admis. Phase 2 : les groupes d'origine, élèves libérés. Deux
    // phases dans des lots distincts : la liste de groupes d'une fiche reçoit
    // d'abord l'ajout, puis le retrait (jamais les deux dans le même lot).
    return [
      ..._pack([
        if (plan.seasonToSave case final next?)
          (cost: 1, apply: () => repositories.seasons.save(next)),
        for (final step in plan.steps)
          (
            cost: 1 + 2 * step.moved,
            apply: () => repositories.groups.save(step.destination),
          ),
      ], max),
      ..._pack([
        for (final step in plan.steps)
          (
            cost: 1 + 2 * step.moved,
            apply: () => repositories.groups.save(step.released),
          ),
      ], max),
    ];
  }

  Future<List<OperationLot>> _purgeInvitations(int max) async {
    final codes = await invitations.codes();
    return [
      for (var i = 0; i < codes.length; i += max)
        invitations.remove(
          codes.sublist(i, i + max > codes.length ? codes.length : i + max),
        ),
    ];
  }

  Future<List<OperationLot>> _finish(int max) async {
    final flagged = (await purge.flagged()).toList();
    return [
      // Rejeu de la purge : une donnée arrivée depuis l'étape de purge (ou la
      // reconduction) est retirée avant la suppression des fiches.
      ...await purge.purgeLots(flagged.toSet(), maxWrites: max),
      for (var i = 0; i < flagged.length; i += max)
        purge.removeRecords(
          flagged
              .sublist(i, i + max > flagged.length ? flagged.length : i + max)
              .toSet(),
        ),
    ];
  }
}

final class _Stage implements OperationStage {
  const _Stage(this._remaining);

  final Future<List<OperationLot>> Function(int max) _remaining;

  @override
  Future<List<OperationLot>> remaining(int maxWrites) => _remaining(maxWrites);
}
