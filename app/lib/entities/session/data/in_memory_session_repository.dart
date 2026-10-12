import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: SessionRepository, env: [Environment.test])
class InMemorySessionRepository implements SessionRepository {
  final Map<String, Session> _sessions = {};

  @override
  Future<List<Session>> getAll() async => List.unmodifiable(_sessions.values);

  @override
  Future<void> add(Session session) async =>
      _sessions.journaledPut(session.id, session);

  @override
  Future<void> delete(String id) async => _sessions.journaledRemove(id);
}
