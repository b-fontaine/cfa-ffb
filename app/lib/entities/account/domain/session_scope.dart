import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Porteur de la session : implémente les deux ports minuscules lus par les
/// dépôts ([CurrentUser], [ActiveClubScope]). Seul `AuthCubit` l'écrit.
class SessionScope implements CurrentUser, ActiveClubScope {
  UserId? _user;
  bool _admin = false;
  ClubId? _club;
  Role? _role;
  List<GroupId> _groups = const [];
  List<StudentId> _students = const [];

  @override
  UserId? get id => _user;

  @override
  bool get isAdmin => _admin;

  @override
  ClubId? get clubId => _club;

  @override
  Role? get role => _role;

  @override
  List<GroupId> get groupIds => _groups;

  @override
  List<StudentId> get studentIds => _students;

  void signIn(UserId user, {bool isAdmin = false}) {
    _user = user;
    _admin = isAdmin;
    deactivateClub();
  }

  void activate(
    ClubId club,
    Role role, {
    List<GroupId> groupIds = const [],
    List<StudentId> studentIds = const [],
  }) {
    _club = club;
    _role = role;
    _groups = List.unmodifiable(groupIds);
    _students = List.unmodifiable(studentIds);
  }

  void deactivateClub() {
    _club = null;
    _role = null;
    _groups = const [];
    _students = const [];
  }

  void signOut() {
    _user = null;
    _admin = false;
    deactivateClub();
  }
}
