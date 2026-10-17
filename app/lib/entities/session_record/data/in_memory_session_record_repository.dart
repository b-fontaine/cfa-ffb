import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: SessionRecordRepository, env: [Environment.test])
class InMemorySessionRecordRepository implements SessionRecordRepository {
  final Map<SessionId, SessionRecord> _sessions = {};

  @override
  Future<void> save(SessionRecord session) async =>
      _sessions.journaledPut(session.id, session);

  @override
  Future<SessionRecord?> byId(SessionId id) async => _sessions[id];

  @override
  Future<List<SessionRecord>> forGroup(GroupId groupId) async =>
      _byDate(_sessions.values.where((s) => s.groupId == groupId));

  @override
  Future<List<SessionRecord>> forStudent(StudentId studentId) async =>
      _byDate(_sessions.values.where((s) => s.present.contains(studentId)));

  @override
  Future<Set<SessionId>> idsEverPresent(StudentId studentId) async => {
    for (final session in _sessions.values)
      if (session.present.contains(studentId)) session.id,
  };

  @override
  Future<List<SessionRecord>> all() async => _sessions.values.toList();

  @override
  Future<void> delete(SessionId id) async => _sessions.journaledRemove(id);

  @override
  Future<void> eraseStudent(StudentId studentId) async {
    for (final session in _sessions.values.toList()) {
      if (!session.present.contains(studentId)) continue;
      _sessions.journaledPut(
        session.id,
        session.copyWith(present: {...session.present}..remove(studentId)),
      );
    }
  }

  List<SessionRecord> _byDate(Iterable<SessionRecord> sessions) =>
      sessions.toList()..sort((a, b) => a.date.compareTo(b.date));
}
