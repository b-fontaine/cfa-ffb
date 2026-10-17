import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/student_showcase/presentation/ui/linked_students_list.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/ui/pump_ui.dart';

void main() {
  Student student(String id, String name) => Student.enroll(
    id: StudentId(id),
    firstName: name,
    audience: Audience.children,
    since: DateTime(2026, 10),
  );

  testWidgets(
    'lists the first name only, and opens the progress of the one tapped',
    (tester) async {
      final opened = <StudentId>[];
      await pumpUi(
        tester,
        LinkedStudentsList(
          students: [student('s1', 'Léa'), student('s2', 'Tom')],
          onShow: opened.add,
        ),
      );

      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
      expect(find.text('See the progress'), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(ListTile).first).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.text('Tom'));
      expect(opened, [const StudentId('s2')]);
    },
  );

  testWidgets('says so when nobody is linked yet', (tester) async {
    await pumpUi(
      tester,
      LinkedStudentsList(students: const [], onShow: (_) {}),
    );
    expect(
      find.text('No student is linked to your account yet.'),
      findsOneWidget,
    );
  });
}
