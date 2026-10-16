import 'dart:io';

import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late GetStudentShowcase showcase;
  var ids = 0;

  Future<void> pass(
    String block,
    int number, {
    bool passed = true,
    int d = 2,
  }) => world.attempts.add(
    attempt(
      ref(block, number),
      potted: passed ? 3 : 0,
      dayOfMonth: d,
      id: 'p${ids++}',
    ),
  );

  Future<StudentShowcase> open() =>
      showcase(const StudentId('s1')).then<StudentShowcase>(ok);

  setUp(() async {
    world = DomainWorld(config: RulesConfig(passesRequired: 2));
    await world.seedClub(studentNames: ['s1', 's2']);
    showcase = GetStudentShowcase(
      world.students,
      world.attempts,
      world.acquisitions,
      world.catalogueRepository,
      world.config,
    );
  });

  test('is to start only without any attempt', () async {
    expect((await open()).toStart, isTrue);

    await pass('a', 1, passed: false);

    expect((await open()).toStart, isFalse);
  });

  test('carries the passes required to validate an exercise', () async {
    expect((await open()).passesRequired, 2);
  });

  test('refuses an unknown student', () async {
    final failure = err(await showcase(const StudentId('ghost')));

    expect(failure, isA<NotFound>().having((e) => e.kind, 'kind', 'student'));
  });

  test(
    'gives the first name and one row per technique with its cells',
    () async {
      final result = await open();

      expect(result.firstName, 's1');
      expect(result.rows.map((r) => r.title), ['Bloc a', 'Bloc b', 'Bloc c']);
      expect(result.rows.first.cells.map((c) => c.number), [1, 2, 3]);
      expect(
        result.rows.expand((r) => r.cells).map((c) => c.state),
        everyElement(ExerciseCellState.todo),
      );
      expect(result.techniqueCount, 3);
      expect(result.validatedCount, 0);
    },
  );

  test(
    'shows the exercise in progress with its successful passes only',
    () async {
      await pass('a', 1);
      await pass('a', 1, passed: false, d: 3);
      await pass('a', 1, passed: false, d: 4);

      final current = (await open()).current!;

      expect(current.number, 1);
      expect(current.blockTitle, 'Bloc a');
      expect(current.passed, 1);
      expect(current.required, 2);
    },
  );

  test(
    'the exercise in progress moves on once the previous one is validated',
    () async {
      await pass('a', 1);
      await pass('a', 1, d: 3);

      final result = await open();

      expect(result.current!.number, 2);
      expect(result.validatedCount, 1);
      expect(result.rows.first.cells.first.state, ExerciseCellState.validated);
    },
  );

  test('a cell carries its successful passes, never its failures', () async {
    await pass('a', 1);
    await pass('a', 1, passed: false, d: 3);
    await pass('a', 2, passed: false, d: 4);

    final cells = (await open()).rows.first.cells;

    expect(cells.map((c) => c.passed), [1, 0, 0]);
    expect(cells.map((c) => c.state), [
      ExerciseCellState.inProgress,
      ExerciseCellState.inProgress,
      ExerciseCellState.todo,
    ]);
  });

  test('shows a block marked acquired as acquired', () async {
    await world.acquisitions.add(acquisition('b'));

    final result = await open();

    expect(result.rows[1].status, ShowcaseRowStatus.acquired);
    expect(
      result.rows[1].cells.map((c) => c.state),
      everyElement(ExerciseCellState.acquired),
    );
    expect(result.validatedCount, 3);
    expect(result.finishedTechniques, 1);
  });

  test(
    'shows a block to review as in progress, with no trace of the alert',
    () async {
      await pass('a', 1, passed: false);
      await pass('a', 1, passed: false, d: 3);
      await pass('a', 1, passed: false, d: 4);

      final result = await open();

      expect(result.rows.first.status, ShowcaseRowStatus.inProgress);
      expect(result.rows.first.cells.first.state, ExerciseCellState.inProgress);
      expect(result.current!.passed, 0);
    },
  );

  test('has no current exercise once the level is finished', () async {
    for (final block in ['a', 'b', 'c']) {
      for (var n = 1; n <= 3; n++) {
        await pass(block, n);
        await pass(block, n, d: 3);
      }
    }

    final result = await open();

    expect(result.current, isNull);
    expect(result.finishedTechniques, 3);
    expect(
      result.rows.map((r) => r.status),
      everyElement(ShowcaseRowStatus.finished),
    );
  });

  test('does not show another student', () async {
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, student: 's2', id: 'other'),
    );

    final result = await open();

    expect(result.rows.first.cells.first.state, ExerciseCellState.todo);
  });

  test(
    'the model has no field about alerts, notes, attendance or others',
    () async {
      await pass('a', 1, passed: false);
      await pass('a', 1, passed: false, d: 3);
      await pass('a', 1, passed: false, d: 4);

      final text = (await open()).toString().toLowerCase();

      for (final forbidden in [
        'alert',
        'failure',
        'comment',
        'assessment',
        'maturity',
        'attendance',
        'audience',
        'score',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  test('the slice imports nothing that could leak private data', () {
    final forbidden = [
      'maturity_assessment',
      'session_record',
      'entities/group',
      'acknowledg',
      'watch_list',
      'track_progress',
      'track_group',
      'attendance',
      'manage_students',
    ];
    final files = Directory('lib/features/student_showcase')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'));

    expect(files, isNotEmpty);
    for (final file in files) {
      final imports = file
          .readAsLinesSync()
          .where((line) => line.startsWith('import '))
          .join('\n');
      for (final word in forbidden) {
        expect(imports, isNot(contains(word)), reason: '${file.path} : $word');
      }
    }
  });
}
