import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_cubit.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_state.dart';
import 'package:billard_cfa/features/administration/presentation/ui/administered_club_card.dart';
import 'package:billard_cfa/features/manage_club/domain/invitable_students.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/club_cubit.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_cubit.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_state.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/club_members_card.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/invite_form.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/issued_invitations_card.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/join_form.dart';
import 'package:billard_cfa/features/student_showcase/presentation/bloc/family_space_cubit.dart';
import 'package:billard_cfa/pages/administration/presentation/administration_page.dart';
import 'package:billard_cfa/pages/club/presentation/club_page.dart';
import 'package:billard_cfa/pages/invite_member/presentation/invite_member_page.dart';
import 'package:billard_cfa/pages/join/presentation/join_page.dart';
import 'package:billard_cfa/pages/my_children/presentation/my_children_page.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/ui/invitation_code_card.dart';
import 'package:billard_cfa/shared/ui/invitation_row.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

const _path = '[Club et rôles]';

final InvitationCode _code = InvitationCode.tryParse('ABCDEFGHJKMN')!;
final _until = DateTime(2026, 10, 14, 9, 30);

Widget _padded(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  ),
);

Role _role(BuildContext context, {List<Role>? options}) =>
    context.knobs.object.dropdown<Role>(
      label: 'Rôle',
      options: options ?? Role.values,
      labelBuilder: (value) => value.name,
    );

/// Un club « Billard Club de Nice » avec ses membres, une invitation émise
/// et la session de [role], dans le monde de démonstration (stock en mémoire).
Future<void> _seed(PreviewWorld world, Role role) async {
  final store = getIt<DocumentStore>() as InMemoryDocumentStore;
  final now = world.today;
  store
    ..seed('clubs/club-nice', {
      'name': 'Billard Club de Nice',
      'createdAt': now,
    })
    ..seed('clubs/club-lyon', {'name': 'Académie de Lyon', 'createdAt': now})
    ..seed('clubs/club-nice/members/u-boss', {
      'uid': 'u-boss',
      'role': 'director',
      'displayName': 'Nadia',
      'groupIds': <String>[],
      'studentIds': <String>[],
      'createdAt': now,
    })
    ..seed('clubs/club-nice/members/u-sophie', {
      'uid': 'u-sophie',
      'role': 'teacher',
      'displayName': 'Sophie',
      'groupIds': [world.childrenGroup.value],
      'studentIds': <String>[],
      'createdAt': now,
    })
    ..seed('clubs/club-nice/members/u-anne', {
      'uid': 'u-anne',
      'role': 'guardian',
      'displayName': 'Anne',
      'groupIds': [world.childrenGroup.value],
      'studentIds': [world.children.id.value],
      'createdAt': now,
    });
  getIt<SessionScope>()
    ..signIn(const UserId('u-boss'), isAdmin: role == Role.admin)
    ..activate(
      const ClubId('club-nice'),
      role,
      groupIds: role == Role.teacher
          ? [world.childrenGroup]
          : const <GroupId>[],
      studentIds: role == Role.student || role == Role.guardian
          ? [world.children.id]
          : const <StudentId>[],
    );
  final invitation = Invitation(
    code: _code,
    clubId: const ClubId('club-nice'),
    role: Role.teacher,
    createdBy: const UserId('u-boss'),
    createdAt: now,
    expiresAt: now.add(const Duration(hours: 48)),
  );
  store.seed('invitations/${_code.value}', {
    'clubId': 'club-nice',
    'role': 'teacher',
    'groupIds': <String>[],
    'studentIds': <String>[],
    'createdBy': 'u-boss',
    'createdAt': now,
    'expiresAt': invitation.expiresAt,
    'used': false,
  });
  await getIt<InvitationLog>().add(
    const UserId('u-boss'),
    const ClubId('club-nice'),
    IssuedInvitation(
      code: _code,
      role: Role.teacher,
      createdAt: now,
      expiresAt: invitation.expiresAt,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Code d’une invitation',
  type: InvitationCodeCard,
  path: _path,
)
Widget buildInvitationCodeCardUseCase(BuildContext context) => _padded(
  InvitationCodeCard(
    code: _code,
    validUntil: _until,
    linkFor: inviteLinkFor(
      context.knobs.boolean(label: 'Web (lien à copier)')
          ? 'https://club.example'
          : null,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Ligne d’invitation',
  type: InvitationRow,
  path: _path,
)
Widget buildInvitationRowUseCase(BuildContext context) => _padded(
  InvitationRow(
    code: _code.readable,
    subtitle: 'Enseignant · En attente',
    revokeLabel: 'Révoquer',
    onRevoke: context.knobs.boolean(label: 'Révocable', initialValue: true)
        ? () {}
        : null,
  ),
);

@widgetbook.UseCase(
  name: 'Équipe et familles',
  type: ClubMembersCard,
  path: _path,
)
Widget buildClubMembersCardUseCase(BuildContext context) => _padded(
  ClubMembersCard(
    members: context.knobs.boolean(label: 'Club vide')
        ? const []
        : [
            Member(
              uid: const UserId('u-boss'),
              role: Role.director,
              displayName: 'Nadia',
            ),
            Member(
              uid: const UserId('u-sophie'),
              role: Role.teacher,
              displayName: 'Sophie',
            ),
            Member(
              uid: const UserId('u-anne'),
              role: Role.guardian,
              displayName: 'Anne',
            ),
          ],
    canRemove: (member) => member.role != Role.director,
    onRemove: (_) {},
  ),
);

@widgetbook.UseCase(
  name: 'Invitations de cet appareil',
  type: IssuedInvitationsCard,
  path: _path,
)
Widget buildIssuedInvitationsCardUseCase(BuildContext context) {
  IssuedInvitationStatus item(
    String code,
    Role role,
    InvitationStatus? status,
  ) => IssuedInvitationStatus(
    IssuedInvitation(
      code: InvitationCode.tryParse(code)!,
      role: role,
      createdAt: DateTime(2026, 10, 12),
      expiresAt: DateTime(2026, 10, 14),
    ),
    status,
  );
  return _padded(
    IssuedInvitationsCard(
      title: 'Invitations envoyées depuis cet appareil',
      invitations: context.knobs.boolean(label: 'Aucune invitation')
          ? const []
          : [
              item('AAAAAAAAAA', Role.teacher, InvitationStatus.waiting),
              item('BBBBBBBBBB', Role.guardian, InvitationStatus.used),
              item('CCCCCCCCCC', Role.student, InvitationStatus.expired),
              item('DDDDDDDDDD', Role.teacher, null),
            ],
      onRevoke: (_) {},
    ),
  );
}

@widgetbook.UseCase(
  name: 'Formulaire d’invitation',
  type: InviteForm,
  path: _path,
)
Widget buildInviteFormUseCase(BuildContext context) => WorldScope(
  builder: (context, world) {
    final role = context.knobs.object.dropdown<Role?>(
      label: 'Rôle invité',
      options: const [null, Role.teacher, Role.student, Role.guardian],
      labelBuilder: (value) => value?.name ?? 'aucun',
    );
    return _padded(
      InviteForm(
        state: InviteState(
          load: InviteLoad.ready,
          roles: const [Role.teacher, Role.student, Role.guardian],
          role: role,
          students: [
            InvitableStudent(
              student: world.children,
              groups: [
                Group(
                  id: world.childrenGroup,
                  seasonId: world.seasonId,
                  name: 'Enfants',
                  audience: Audience.children,
                ),
              ],
            ),
          ],
          ageConfirmed: context.knobs.boolean(label: 'Case « 15 ans ou plus »'),
          submitting: context.knobs.boolean(label: 'Envoi en cours'),
        ),
        onRole: (_) {},
        onGroup: (_) {},
        onStudent: (_) {},
        onAge: (_) {},
        onSubmit: () {},
      ),
    );
  },
);

@widgetbook.UseCase(
  name: 'Formulaire « Rejoindre un club »',
  type: JoinForm,
  path: _path,
)
Widget buildJoinFormUseCase(BuildContext context) => _padded(
  JoinForm(
    initialCode: context.knobs.boolean(label: 'Code prérempli (lien)')
        ? _code.value
        : null,
    state: JoinState(
      status: context.knobs.object.dropdown<JoinStatus>(
        label: 'Avancement',
        options: JoinStatus.values,
        labelBuilder: (value) => value.name,
      ),
      failure: context.knobs.object.dropdown<JoinFailureCode?>(
        label: 'Échec (si « failed »)',
        options: [null, ...JoinFailureCode.values],
        labelBuilder: (value) => value?.name ?? 'aucun',
      ),
    ),
    onSubmit: (_, _) {},
  ),
);

@widgetbook.UseCase(
  name: 'Club à administrer',
  type: AdministeredClubCard,
  path: _path,
)
Widget buildAdministeredClubCardUseCase(BuildContext context) => _padded(
  AdministeredClubCard(
    entry: AdministeredClub(
      club: Club(id: const ClubId('club-nice'), name: 'Billard Club de Nice'),
      invitations: context.knobs.boolean(label: 'Avec une invitation')
          ? [
              IssuedInvitationStatus(
                IssuedInvitation(
                  code: _code,
                  role: Role.director,
                  createdAt: DateTime(2026, 10, 12),
                  expiresAt: _until,
                ),
                InvitationStatus.waiting,
              ),
            ]
          : const [],
    ),
    onInviteDirector: () {},
    onRevoke: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Mon club', type: ClubPage, path: _path)
Widget buildClubPageUseCase(BuildContext context) {
  final role = _role(
    context,
    options: const [Role.teacher, Role.director, Role.admin],
  );
  return _SeededScope(
    role: role,
    builder: (context) => BlocProvider(
      create: (_) {
        final cubit = getIt<ClubCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: ClubPage(
        clubName: 'Billard Club de Nice',
        onInvite: () {},
        onBack: () {},
        onRenamed: () {},
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Inviter quelqu’un',
  type: InviteMemberPage,
  path: _path,
)
Widget buildInviteMemberPageUseCase(BuildContext context) {
  final role = _role(context, options: const [Role.teacher, Role.director]);
  return _SeededScope(
    role: role,
    builder: (context) => BlocProvider(
      create: (_) {
        final cubit = getIt<InviteCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: InviteMemberPage(
        onBack: () {},
        linkFor: inviteLinkFor('https://club.example'),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Rejoindre un club', type: JoinPage, path: _path)
Widget buildJoinPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) => getIt<JoinCubit>(),
    child: JoinPage(
      initialCode: _code.value,
      onJoined: () {},
      onSignOut: context.knobs.boolean(label: 'Compte sans club')
          ? () {}
          : null,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Administration',
  type: AdministrationPage,
  path: _path,
)
Widget buildAdministrationPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => FutureBuilder<void>(
    future: _seed(world, Role.admin),
    builder: (context, snapshot) =>
        snapshot.connectionState == ConnectionState.done
        ? BlocProvider(
            create: (_) {
              final cubit = getIt<AdministrationCubit>();
              unawaited(cubit.load());
              return cubit;
            },
            child: AdministrationPage(onBack: () {}),
          )
        : const SizedBox.shrink(),
  ),
);

@widgetbook.UseCase(
  name: 'Mes enfants / Ma progression',
  type: MyChildrenPage,
  path: _path,
)
Widget buildMyChildrenPageUseCase(BuildContext context) {
  final student = context.knobs.boolean(label: 'Compte d’élève (sinon parent)');
  return _SeededScope(
    role: student ? Role.student : Role.guardian,
    builder: (context) => BlocProvider(
      create: (_) {
        final cubit = getIt<FamilySpaceCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: MyChildrenPage(studentOwnAccount: student),
    ),
  );
}

/// Amorce le club de démonstration (stock en mémoire, session du rôle donné)
/// une seule fois, puis construit la page.
class _SeededScope extends StatefulWidget {
  const _SeededScope({required this.role, required this.builder});

  final Role role;
  final WidgetBuilder builder;

  @override
  State<_SeededScope> createState() => _SeededScopeState();
}

class _SeededScopeState extends State<_SeededScope> {
  late final Future<void> _ready = PreviewWorld.ensure().then(
    (world) => _seed(world, widget.role),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) =>
        snapshot.connectionState == ConnectionState.done
        ? widget.builder(context)
        : const LoadingView(),
  );
}
