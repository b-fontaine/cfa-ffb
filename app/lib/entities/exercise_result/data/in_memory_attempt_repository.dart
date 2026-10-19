import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/change_feed.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD) ; la persistance locale (drift)
/// vit derrière le même port (ADR 0001).
@LazySingleton(as: AttemptRepository, env: [Environment.test])
class InMemoryAttemptRepository implements AttemptRepository {
  final ObservedMap<AttemptId, ExerciseAttempt> _attempts = ObservedMap();

  @override
  Future<void> add(ExerciseAttempt attempt) async =>
      _attempts.journaledPut(attempt.id, attempt);

  @override
  Future<void> correct(ExerciseAttempt attempt) async {
    final existing = _attempts[attempt.id];
    if (existing == null) throw NotFound('attempt', attempt.id.value);
    _attempts.journaledPut(
      attempt.id,
      existing.copyWith(potted: attempt.potted, total: attempt.total),
    );
  }

  @override
  Future<List<ExerciseAttempt>> forStudent(StudentId studentId) async => [
    for (final attempt in _attempts.values)
      if (attempt.studentId == studentId) attempt,
  ];

  @override
  Future<List<ExerciseAttempt>> forSession(SessionId sessionId) async => [
    for (final attempt in _attempts.values)
      if (attempt.sessionId == sessionId) attempt,
  ];

  @override
  Future<List<ExerciseAttempt>> all() async => _attempts.values.toList();

  @override
  Future<void> delete(AttemptId id) async => _attempts.journaledRemove(id);

  @override
  Future<void> eraseStudent(StudentId studentId) async {
    for (final attempt in _attempts.values.toList()) {
      if (attempt.studentId == studentId) _attempts.journaledRemove(attempt.id);
    }
  }

  @override
  Stream<List<ExerciseAttempt>> watchForStudent(StudentId studentId) =>
      _attempts.watch(() => forStudent(studentId));

  @override
  Stream<List<ExerciseAttempt>> watchForSession(SessionId sessionId) =>
      _attempts.watch(() => forSession(sessionId));

  @override
  Stream<List<ExerciseAttempt>> watchAll() => _attempts.watch(all);
}
