import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/entities/club/domain/club_repository.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : créer un club (administrateur seulement, sans club actif
/// requis : le premier club d'une plateforme vide). Le nom est borné ; le club
/// reçoit un identifiant tiré au hasard.
@injectable
class CreateClub {
  CreateClub(this._clubs, this._ids, this._user);

  final ClubRepository _clubs;
  final IdGenerator _ids;
  final CurrentUser _user;

  Future<Result<Club>> call(String name) => runGuarded(() async {
    requireAdmin(_user);
    final club = Club(id: ClubId(_ids.next()), name: name.trim());
    await _clubs.create(club);
    return club;
  });
}
