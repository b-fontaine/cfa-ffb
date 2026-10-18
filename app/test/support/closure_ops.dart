import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/domain/prepare_season_closure.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tracking_world.dart';

/// Opérations de clôture des scénarios du lot 11 : le plan demandé, le
/// dernier résultat de clôture (accepté, refusé ou en échec technique) et la
/// sauvegarde d'avant la clôture.
class ClosureOps {
  static Result<ClosurePlan>? plan;
  static Result<ClosureResult>? lastClose;
  static Object? crash;
  static String? beforeClosure;

  static void reset() {
    plan = null;
    lastClose = null;
    crash = null;
    beforeClosure = null;
  }

  static ClosurePlan get currentPlan {
    final result = plan;
    if (result is Ok<ClosurePlan>) return result.value;
    return fail('plan de clôture absent ou refusé : $result');
  }

  static Future<void> prepare() async {
    plan = await getIt<PrepareSeasonClosure>()(
      seasonId: TrackingWorld.seasonId,
      today: TrackingWorld.today,
    );
  }

  static Set<StudentId> _students(String names) => {
    if (names.trim().isNotEmpty)
      for (final name in TrackingWorld.names(names))
        TrackingWorld.studentId(name),
  };

  /// Clôt la saison et attend un succès ([expectOk]) ou garde le résultat.
  static Future<void> close(
    String date,
    String erase, {
    bool expectOk = true,
  }) async {
    crash = null;
    try {
      lastClose = await getIt<CloseSeason>()(
        seasonId: TrackingWorld.seasonId,
        closedOn: TrackingWorld.date(date),
        erase: _students(erase),
      );
    } on Object catch (error) {
      crash = error;
      lastClose = null;
    }
    if (expectOk) {
      expect(crash, isNull);
      expect(lastClose, isA<Ok<ClosureResult>>(), reason: '$lastClose');
    }
  }

  static ClosureResult get result {
    final value = lastClose;
    if (value is Ok<ClosureResult>) return value.value;
    return fail('clôture absente ou refusée : $value');
  }

  static Future<Season> season(String label) async {
    final seasons = await getIt<SeasonRepository>().all();
    return seasons.firstWhere(
      (s) => s.label == label,
      orElse: () => fail('saison introuvable : $label'),
    );
  }

  /// Remplace le dépôt de passages par un dépôt dont l'effacement échoue.
  static Future<void> failNextErasure() async {
    final inner = getIt<AttemptRepository>();
    await getIt.unregister<AttemptRepository>();
    getIt.registerSingleton<AttemptRepository>(_FailingErasure(inner));
  }
}

class _FailingErasure implements AttemptRepository {
  _FailingErasure(this._inner);

  final AttemptRepository _inner;

  @override
  Future<void> eraseStudent(StudentId studentId) async =>
      throw StateError('effacement impossible');

  @override
  Future<void> add(ExerciseAttempt attempt) => _inner.add(attempt);

  @override
  Future<void> correct(ExerciseAttempt attempt) => _inner.correct(attempt);

  @override
  Future<List<ExerciseAttempt>> all() => _inner.all();

  @override
  Future<void> delete(AttemptId id) => _inner.delete(id);

  @override
  Future<List<ExerciseAttempt>> forSession(SessionId sessionId) =>
      _inner.forSession(sessionId);

  @override
  Future<List<ExerciseAttempt>> forStudent(StudentId studentId) =>
      _inner.forStudent(studentId);
}
