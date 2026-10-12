import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : lister les séances planifiées.
@injectable
class ListSessions {
  ListSessions(this._repository);

  final SessionRepository _repository;

  Future<List<Session>> call() => _repository.getAll();
}
