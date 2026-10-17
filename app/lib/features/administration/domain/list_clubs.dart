import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/entities/club/domain/club_repository.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : tous les clubs, par nom (administrateur seulement).
@injectable
class ListClubs {
  ListClubs(this._clubs, this._user);

  final ClubRepository _clubs;
  final CurrentUser _user;

  Future<Result<List<Club>>> call() => runGuarded(() async {
    requireAdmin(_user);
    final clubs = [...await _clubs.all()]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return clubs;
  });
}
