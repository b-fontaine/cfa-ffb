import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/club/data/store_club_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/invitation/data/invitation_code_sources.dart';
import 'package:billard_cfa/entities/invitation/data/key_value_invitation_log.dart';
import 'package:billard_cfa/entities/invitation/data/store_invitation_repository.dart';
import 'package:billard_cfa/entities/membership/data/store_member_repository.dart';
import 'package:billard_cfa/entities/membership/data/store_memberships_source.dart';
import 'package:billard_cfa/entities/student/data/store_student_directory.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';

import 'domain_world.dart';
import 'fixed_clock.dart';

/// Un club en mémoire pour les cas d'usage de FB3 : les **vrais** dépôts du
/// stock de documents sur un `InMemoryDocumentStore`, l'horloge figée au
/// lundi 12 octobre 2026 à 9 h 30, et la session (`SessionScope`) à régler par
/// [signIn]. Les élèves et groupes locaux viennent de [DomainWorld].
class ClubWorld {
  ClubWorld() : clock = FixedClock(DateTime(2026, 10, 12, 9, 30)) {
    store.serverNow = clock.now;
    clubs = StoreClubRepository(store);
    members = StoreMemberRepository(store);
    memberships = StoreMembershipsSource(store);
    invitations = StoreInvitationRepository(store, clock);
    directory = StoreStudentDirectory(store);
    log = KeyValueInvitationLog(keyValues);
  }

  final FixedClock clock;
  final InMemoryDocumentStore store = InMemoryDocumentStore();
  final InMemoryKeyValueStore keyValues = InMemoryKeyValueStore();
  final DomainWorld local = DomainWorld();
  final SessionScope scope = SessionScope();
  final SequentialInvitationCodeSource codes = SequentialInvitationCodeSource();

  late final StoreClubRepository clubs;
  late final StoreMemberRepository members;
  late final StoreMembershipsSource memberships;
  late final StoreInvitationRepository invitations;
  late final StoreStudentDirectory directory;
  late final KeyValueInvitationLog log;

  static const club = ClubId('c1');
  static const director = UserId('u-director');

  /// Connecte [user] dans le club `c1` avec [role] et son périmètre.
  void signIn(
    Role role, {
    UserId user = director,
    List<GroupId> groupIds = const [],
    List<StudentId> studentIds = const [],
    bool isAdmin = false,
  }) {
    scope
      ..signIn(user, isAdmin: isAdmin)
      ..activate(club, role, groupIds: groupIds, studentIds: studentIds);
  }

  /// Le club `c1` et un document `members` pour [uid].
  void seedMember(
    String uid,
    Role role, {
    String? name,
    List<String> groups = const [],
    List<String> students = const [],
    String clubId = 'c1',
    String clubName = 'Club un',
  }) {
    store
      ..seed('clubs/$clubId', {'name': clubName, 'createdAt': clock.now()})
      ..seed('clubs/$clubId/members/$uid', {
        'uid': uid,
        'role': role.name,
        'displayName': name ?? uid,
        'groupIds': groups,
        'studentIds': students,
        'createdAt': clock.now(),
      });
  }

  /// Élèves et groupes locaux : `s1` (Léa) et `s2` (Tom) dans le groupe `g1`
  /// (« Mardi », enfants) ; `s3` (Marc) dans `g2` (« Jeudi », adultes).
  Future<void> seedLocalClub() async {
    final start = DateTime(2026, 10);
    await local.seedClub(studentNames: ['s1', 's2']);
    for (final (id, name) in [('s1', 'Léa'), ('s2', 'Tom')]) {
      await local.students.save(
        Student.enroll(
          id: StudentId(id),
          firstName: name,
          audience: Audience.children,
          since: start,
        ),
      );
    }
    await local.groups.save(
      (await local.groups.byId(const GroupId('g1')))!.rename('Mardi'),
    );
    await local.students.save(
      Student.enroll(
        id: const StudentId('s3'),
        firstName: 'Marc',
        audience: Audience.adults,
        since: start,
      ),
    );
    await local.groups.save(
      Group(
        id: const GroupId('g2'),
        seasonId: const SeasonId('season'),
        name: 'Jeudi',
        audience: Audience.adults,
      ).admit(
        studentId: const StudentId('s3'),
        studentAudience: Audience.adults,
        from: start,
      ),
    );
  }

  Fields? doc(String path) => store.read(path);
}
