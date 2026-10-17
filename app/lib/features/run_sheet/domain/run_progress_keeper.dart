import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_links.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// La saisie des résultats ouverte depuis la séance guidée, relue de la
/// saisie elle-même (jamais copiée dans la progression, ADR 0020 D2) : son
/// identifiant, son groupe, sa date et les élèves du groupe qui n'y étaient
/// pas.
typedef RunRecordLink = ({
  SessionId recordId,
  GroupId group,
  DateTime date,
  Set<StudentId> absent,
});

/// Garde et relit l'état des séances guidées en cours (lot 10b, ADR 0020).
///
/// Le seul point de contact du guide avec la persistance : le cubit écrit et
/// relit sa progression, le registre des séances en cours la purge et la
/// liste au démarrage. Une écriture peut échouer ; l'appelant décide quoi en
/// faire (D10 : jamais bloquant).
@injectable
class RunProgressKeeper {
  RunProgressKeeper(this._progress, this._records, this._groups, this._clock);

  /// Une séance guidée laissée sans « Terminer » ni « Abandonner » est oubliée
  /// au bout de ce délai `[Prop]` (minimisation, D8).
  static const staleAfter = Duration(days: 7);

  final RunProgressRepository _progress;
  final SessionRecordRepository _records;
  final GroupRepository _groups;
  final Clock _clock;

  /// La progression enregistrée de [key], `null` s'il n'y en a pas.
  Future<RunProgress?> saved(RunProgressKey key) => _progress.byKey(key);

  /// Toutes les progressions enregistrées, de la plus récente à la plus
  /// ancienne.
  Future<List<RunProgress>> all() => _progress.all();

  /// Les séances effacées de force (droit à l'effacement d'un élève) : ceux
  /// qui gardent un guide en mémoire doivent le libérer.
  Stream<RunProgressLinks> get erasures => _progress.erased;

  /// Enregistre l'état de [key], daté de maintenant ; remplace le précédent.
  Future<void> save({
    required RunProgressKey key,
    int step = 0,
    Map<String, int> counts = const {},
    Map<String, Set<int>> checked = const {},
    int scoreA = 0,
    int scoreB = 0,
    int timerSeconds = 0,
    SessionId? recordId,
  }) => _progress.save(
    RunProgress(
      key: key,
      updatedAt: _clock.now(),
      step: step,
      counts: counts,
      checked: checked,
      scoreA: scoreA,
      scoreB: scoreB,
      timerSeconds: timerSeconds,
      recordId: recordId,
    ),
  );

  /// Oublie la progression de [key] ; sans effet s'il n'y en a pas.
  Future<void> forget(RunProgressKey key) => _progress.delete(key);

  /// Oublie les progressions plus vieilles que [staleAfter] ; renvoie combien.
  Future<int> purgeStale() =>
      _progress.purgeOlderThan(_clock.now().subtract(staleAfter));

  /// La saisie [recordId] telle que le guide la retient, `null` si elle
  /// n'existe plus (ou a été supprimée).
  ///
  /// Les absents sont les élèves du groupe à la date de la saisie qui n'y
  /// figurent pas : ce que la saisie contient, rien de plus. Si le groupe a
  /// disparu depuis, il n'y a plus d'absent à proposer.
  Future<RunRecordLink?> recordLink(SessionId recordId) async {
    final record = await _records.byId(recordId);
    if (record == null) return null;
    final group = await _groups.byId(record.groupId);
    final members = group?.membersOn(record.date) ?? const <StudentId>[];
    return (
      recordId: record.id,
      group: record.groupId,
      date: record.date,
      absent: {
        for (final member in members)
          if (!record.present.contains(member)) member,
      },
    );
  }
}
