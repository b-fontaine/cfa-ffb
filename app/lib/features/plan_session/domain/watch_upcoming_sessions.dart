import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/changes.dart';
import 'package:injectable/injectable.dart';

/// Les changements des données de la séance du jour et des séances à venir
/// (FB5b) : séances planifiées, séances données (une séance planifiée devient
/// « donnée » quand un autre appareil la saisit) et groupes (leur nom). La
/// section se recharge par `GetUpcomingSessions`.
@injectable
class WatchUpcomingSessions {
  WatchUpcomingSessions(this._sessions, this._records, this._groups);

  final SessionRepository _sessions;
  final SessionRecordRepository _records;
  final GroupRepository _groups;

  Stream<void> call() => changesOf([
    _sessions.watchAll(),
    _records.watchAll(),
    _groups.watchAll(),
  ]);
}
