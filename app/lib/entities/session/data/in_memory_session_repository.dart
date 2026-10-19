import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/change_feed.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: SessionRepository, env: [Environment.test])
class InMemorySessionRepository implements SessionRepository {
  final ObservedMap<String, Session> _sessions = ObservedMap();

  @override
  Future<List<Session>> getAll() async => List.unmodifiable(_sessions.values);

  @override
  Future<Set<String>> idsOfGroups(Set<GroupId> groups) async => {
    for (final session in _sessions.values)
      if (groups.contains(session.groupId)) session.id,
  };

  @override
  Future<void> add(Session session) async =>
      _sessions.journaledPut(session.id, session);

  @override
  Future<void> delete(String id) async => _sessions.journaledRemove(id);

  @override
  Stream<List<Session>> watchAll() => _sessions.watch(getAll);
}
