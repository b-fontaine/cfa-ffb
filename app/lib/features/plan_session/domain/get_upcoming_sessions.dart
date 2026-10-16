import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la prochaine séance et les séances à noter, vues du jour
/// (horloge injectée).
@injectable
class GetUpcomingSessions {
  GetUpcomingSessions(this._list, this._groups, this._clock);

  final ListSessions _list;
  final GroupRepository _groups;
  final Clock _clock;

  Future<Result<UpcomingSessions>> call() => runGuarded(() async {
    final summaries = await _list();
    final groups = await _groups.all();
    return upcomingOf(
      summaries,
      _clock.today(),
      groupNames: {for (final group in groups) group.id: group.name},
    );
  });
}
