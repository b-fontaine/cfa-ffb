import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Porteur de la session : implémente les deux ports minuscules lus par les
/// dépôts ([CurrentUser], [ActiveClubScope]). Seul `AuthCubit` l'écrit.
class SessionScope implements CurrentUser, ActiveClubScope {
  UserId? _user;
  ClubId? _club;
  Role? _role;

  @override
  UserId? get id => _user;

  @override
  ClubId? get clubId => _club;

  @override
  Role? get role => _role;

  void signIn(UserId user) {
    _user = user;
    _club = null;
    _role = null;
  }

  void activate(ClubId club, Role role) {
    _club = club;
    _role = role;
  }

  void deactivateClub() {
    _club = null;
    _role = null;
  }

  void signOut() {
    _user = null;
    deactivateClub();
  }
}
