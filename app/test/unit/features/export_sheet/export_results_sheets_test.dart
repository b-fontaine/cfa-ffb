import 'dart:convert';

import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_export_source.dart';
import '../../../support/fake_print_renderer.dart';
import '../../../support/fixed_clock.dart';

/// Compte les lectures : preuve qu'aucun dépôt d'élèves n'est lu.
class _Reads {
  int count = 0;

  Never read() {
    count++;
    throw StateError("lecture d'un dépôt d'élèves interdite");
  }
}

class _UnreadableStudents implements StudentRepository {
  _UnreadableStudents(this._reads);

  final _Reads _reads;

  @override
  dynamic noSuchMethod(Invocation invocation) => _reads.read();
}

class _UnreadableGroups implements GroupRepository {
  _UnreadableGroups(this._reads);

  final _Reads _reads;

  @override
  dynamic noSuchMethod(Invocation invocation) => _reads.read();
}

const _series = [
  ResultsSeries(
    session: 'S',
    exercise: '1. E',
    notion: 'N',
    technique: 'T',
    attempts: 10,
  ),
];

ResultsSheetsRequest _request({GroupId? group, int columns = 5}) =>
    ResultsSheetsRequest(
      title: 'Fiches',
      fileName: 'fiches-x-enfants.pdf',
      series: _series,
      columns: columns,
      labels: testResultsLabels(),
      groupId: group,
    );

Iterable<String> _names(ExportedDocument document) => document.document.pages
    .expand((p) => p.items)
    .whereType<PrintText>()
    .where((t) => t.tag == 'student-name')
    .map((t) => t.text);

void main() {
  final today = DateTime(2026, 10, 12);
  late InMemoryGroupRepository groups;
  late InMemoryStudentRepository students;
  late FakePrintRenderer renderer;

  ExportResultsSheets useCase() =>
      ExportResultsSheets(renderer, groups, students, FixedClock(today));

  Student student(String id, String name) => Student.enroll(
    id: StudentId(id),
    firstName: name,
    audience: Audience.children,
    since: DateTime(2026, 9),
  );

  setUp(() async {
    groups = InMemoryGroupRepository();
    students = InMemoryStudentRepository();
    renderer = FakePrintRenderer();
  });

  test('renders blank grids and names the file, without any group', () async {
    final result = await useCase()(_request());

    final document = (result as Ok<ExportedDocument>).value;
    expect(document.fileName, 'fiches-x-enfants.pdf');
    expect(document.document.pages, hasLength(2));
    expect(_names(document), isEmpty);
    expect(utf8.decode(document.bytes), 'PDF 2');
  });

  test('reads no student and no group when no group is asked for', () async {
    final reads = _Reads();

    final result = await ExportResultsSheets(
      renderer,
      _UnreadableGroups(reads),
      _UnreadableStudents(reads),
      FixedClock(today),
    )(_request());

    expect(result, isA<Ok<ExportedDocument>>());
    expect(reads.count, 0);
  });

  group('with the first names of a group', () {
    Future<void> seed() async {
      await students.save(student('1', 'Zoé'));
      await students.save(student('2', 'Éloïse'));
      await students.save(student('3', 'Anna'));
      await students.save(student('4', 'Hugo'));
      await students.save(student('5', 'Ancien'));
      await groups.save(
        Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('s'),
          name: 'Mardi',
          audience: Audience.children,
          memberships: [
            Membership(
              studentId: const StudentId('1'),
              from: DateTime(2026, 9),
            ),
            Membership(
              studentId: const StudentId('2'),
              from: DateTime(2026, 9),
            ),
            Membership(
              studentId: const StudentId('3'),
              from: DateTime(2026, 9),
            ),
            Membership(
              studentId: const StudentId('5'),
              from: DateTime(2026, 9),
              to: DateTime(2026, 10),
            ),
          ],
        ),
      );
    }

    test(
      'prints the current members, sorted without regard to accents',
      () async {
        await seed();

        final result = await useCase()(_request(group: const GroupId('g1')));

        expect(_names((result as Ok<ExportedDocument>).value), [
          'Anna',
          'Éloïse',
          'Zoé',
        ]);
      },
    );

    test('prints a name without the spaces around it', () async {
      await students.save(student('9', '  Inès '));
      await groups.save(
        Group(
          id: const GroupId('g9'),
          seasonId: const SeasonId('s'),
          name: 'Jeudi',
          audience: Audience.children,
          memberships: [
            Membership(
              studentId: const StudentId('9'),
              from: DateTime(2026, 9),
            ),
          ],
        ),
      );

      final result = await useCase()(_request(group: const GroupId('g9')));

      expect(_names((result as Ok<ExportedDocument>).value), ['Inès']);
    });

    test('leaves out students of other groups and past members', () async {
      await seed();

      final result = await useCase()(_request(group: const GroupId('g1')));

      final names = _names((result as Ok<ExportedDocument>).value);
      expect(names, isNot(contains('Hugo')));
      expect(names, isNot(contains('Ancien')));
    });

    test(
      'prints first names only, never anything else about the student',
      () async {
        await seed();

        final result = await useCase()(_request(group: const GroupId('g1')));

        final texts = (result as Ok<ExportedDocument>).value.document.pages
            .expand((p) => p.items)
            .whereType<PrintText>()
            .map((t) => t.text)
            .join(' ');
        expect(texts, isNot(contains('Mardi')));
      },
    );

    test('rejects an unknown group', () async {
      final result = await useCase()(_request(group: const GroupId('nope')));

      expect(
        (result as Err<ExportedDocument>).failure,
        isA<NotFound>().having((f) => f.kind, 'kind', 'group'),
      );
      expect(renderer.rendered, isEmpty);
    });
  });

  test('passes the number of columns on to the layout', () async {
    final result = await useCase()(_request(columns: 6));

    final heads = (result as Ok<ExportedDocument>)
        .value
        .document
        .pages
        .first
        .items
        .whereType<PrintText>()
        .where((t) => t.tag == 'attempt-head' && t.text == '6');
    expect(heads, hasLength(4));
  });
}
