import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_club/domain/invitable_students.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_state.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/invite_form.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../shared/ui/pump_ui.dart';

void main() {
  final mardi = Group(
    id: const GroupId('g1'),
    seasonId: const SeasonId('s'),
    name: 'Mardi',
    audience: Audience.children,
  );
  final lea = InvitableStudent(
    student: Student.enroll(
      id: const StudentId('s1'),
      firstName: 'Léa',
      audience: Audience.children,
      since: DateTime(2026, 10),
    ),
    groups: [mardi],
  );

  late List<String> log;

  Future<void> pump(
    WidgetTester tester,
    InviteState state, {
    Locale locale = const Locale('en'),
  }) => pumpUi(
    tester,
    SingleChildScrollView(
      child: InviteForm(
        state: state,
        onRole: (r) => log.add('role ${r.name}'),
        onGroup: (g) => log.add('group ${g.value}'),
        onStudent: (s) => log.add('student ${s.value}'),
        onAge: (v) => log.add('age $v'),
        onSubmit: () => log.add('submit'),
      ),
    ),
    locale: locale,
  );

  setUp(() => log = []);

  testWidgets('proposes only the roles it is given and reports the choice', (
    tester,
  ) async {
    await pump(
      tester,
      const InviteState(
        load: InviteLoad.ready,
        roles: [Role.student, Role.guardian],
      ),
    );

    expect(find.text('Who do you invite?'), findsOneWidget);
    expect(find.text('Teacher'), findsNothing);
    await tester.tap(find.text('Parent'));
    expect(log, ['role guardian']);
  });

  testWidgets(
    'shows nothing but the roles until one is chosen; submit is off',
    (tester) async {
      await pump(
        tester,
        const InviteState(
          load: InviteLoad.ready,
          roles: [Role.teacher, Role.student],
        ),
      );

      expect(find.text('Which student?'), findsNothing);
      expect(find.text('Groups of the teacher (optional)'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create the invitation'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('a teacher invitation lists the groups, or says there is none', (
    tester,
  ) async {
    await pump(
      tester,
      InviteState(
        load: InviteLoad.ready,
        roles: const [Role.teacher],
        role: Role.teacher,
        groups: [mardi],
        selectedGroups: {mardi.id},
      ),
    );

    expect(find.text('Mardi'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('Mardi'));
    expect(log, ['group g1']);

    await pump(
      tester,
      const InviteState(
        load: InviteLoad.ready,
        roles: [Role.teacher],
        role: Role.teacher,
      ),
    );
    expect(find.text('No group yet.'), findsOneWidget);
  });

  testWidgets(
    'a student invitation lists students with their group and asks the age',
    (tester) async {
      await pump(
        tester,
        InviteState(
          load: InviteLoad.ready,
          roles: const [Role.student],
          role: Role.student,
          students: [lea],
        ),
      );

      expect(find.text('Which student?'), findsOneWidget);
      expect(find.text('Léa · Mardi'), findsOneWidget);
      expect(find.text('This student is 15 or older'), findsOneWidget);
      expect(find.textContaining('No age is stored'), findsOneWidget);
      expect(find.textContaining('information notice'), findsOneWidget);
      await tester.tap(find.text('Léa · Mardi'));
      await tester.tap(find.text('This student is 15 or older'));
      expect(log, ['student s1', 'age true']);
    },
  );

  testWidgets(
    'a parent invitation has no age box and names the limit of children',
    (tester) async {
      await pump(
        tester,
        InviteState(
          load: InviteLoad.ready,
          roles: const [Role.guardian],
          role: Role.guardian,
          students: [lea],
        ),
      );

      expect(find.text('Which children? (up to 4)'), findsOneWidget);
      expect(find.text('This student is 15 or older'), findsNothing);
    },
  );

  testWidgets('without students, it says so', (tester) async {
    await pump(
      tester,
      const InviteState(
        load: InviteLoad.ready,
        roles: [Role.guardian],
        role: Role.guardian,
      ),
    );
    expect(
      find.text('No student available. Add students first.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a failure is announced, and submit goes through when a role is chosen',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        InviteState(
          load: InviteLoad.ready,
          roles: const [Role.teacher],
          role: Role.teacher,
          failure: const InvariantViolation(InvariantCode.actionNotAllowed),
          groups: [mardi],
        ),
      );

      expect(
        find.text('Your role does not allow this action.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Create the invitation'));
      expect(log, ['submit']);
      semantics.dispose();
    },
  );

  testWidgets('while submitting, the role chips and the button are inert', (
    tester,
  ) async {
    await pump(
      tester,
      const InviteState(
        load: InviteLoad.ready,
        roles: [Role.teacher],
        role: Role.teacher,
        submitting: true,
      ),
    );

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create the invitation'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip)).onSelected,
      isNull,
    );
  });

  testWidgets('every row of the form is at least 48 dp', (tester) async {
    await pump(
      tester,
      InviteState(
        load: InviteLoad.ready,
        roles: const [Role.student],
        role: Role.student,
        students: [lea],
      ),
    );

    for (final row in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(row.onChanged, isNotNull);
    }
    for (final finder in [
      find.byType(CheckboxListTile),
      find.byType(ChoiceChip),
      find.byType(FilledButton),
    ]) {
      for (final element in finder.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    }
  });

  testWidgets('is available in French', (tester) async {
    await pump(
      tester,
      const InviteState(
        load: InviteLoad.ready,
        roles: [Role.teacher, Role.student, Role.guardian],
      ),
      locale: const Locale('fr'),
    );
    expect(find.text('Qui invitez-vous ?'), findsOneWidget);
    expect(find.text('Enseignant'), findsOneWidget);
    expect(find.text('Créer l’invitation'), findsOneWidget);
  });
}
