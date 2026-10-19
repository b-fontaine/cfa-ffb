import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_names.dart';
import 'package:billard_cfa/entities/membership/domain/own_link_source.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/changes.dart';
import 'package:injectable/injectable.dart';

/// Les changements de ce que voit un parent ou un élève (FB6) : **chaque**
/// fiche liée, ses passages et ses blocs acquis, les séances planifiées et les
/// groupes de son périmètre, et son propre lien au club (l'accès retiré est
/// ainsi connu sans attendre une donnée). Les mêmes lectures que
/// `GetFamilySpace`, en flux : aucune écoute de plus (les règles les
/// refuseraient). L'écran se recharge par `GetFamilySpace`.
@injectable
class WatchFamilySpace {
  WatchFamilySpace(
    this._students,
    this._attempts,
    this._acquisitions,
    this._sessions,
    this._groupNames,
    this._link,
    this._scope,
  );

  final StudentRepository _students;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final SessionRepository _sessions;
  final GroupNames _groupNames;
  final OwnLinkSource _link;
  final ActiveClubScope _scope;

  Stream<void> call() => changesOf([
    _link.watch(),
    _sessions.watchAll(),
    _groupNames.watch(),
    for (final id in _scope.studentIds) ...[
      _students.watchById(id),
      _attempts.watchForStudent(id),
      _acquisitions.watchForStudent(id),
    ],
  ]);
}
