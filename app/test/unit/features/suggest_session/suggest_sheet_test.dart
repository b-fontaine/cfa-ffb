import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_sheet.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

/// Bloc `coule` : `coule-1` (1-3), `coule-2` (4-6), `coule-3` (7-8) ; bloc
/// `quart-finesses` : `quart-1` (1-2) puis `finesse-1` (3-4) ; bloc `solo`
/// sans séance (aucune dans la liste).
List<SessionSheet> sheets() => [
  _sheet('coule', 1, 1, [1, 2, 3]),
  _sheet('coule', 2, 2, [4, 5, 6]),
  _sheet('coule', 3, 3, [7, 8]),
  _sheet('quart', 4, 1, [1, 2], block: 'quart-finesses'),
  _sheet('finesse', 5, 1, [3, 4], block: 'quart-finesses'),
];

SessionSheet _sheet(
  String technique,
  int order,
  int part,
  List<int> numbers, {
  String? block,
}) => buildSheet(
  technique: technique,
  part: part,
  order: order,
  previous: order == 1 ? null : 'avant-$order',
  block: block ?? technique,
  exercises: [
    for (final n in numbers) sheetExercise('e$n', n, block: block ?? technique),
  ],
);

SessionRecord record(
  String id,
  String? sheet, {
  int dayOfMonth = 1,
  String group = 'g1',
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('season'),
  date: day(dayOfMonth),
  audience: Audience.children,
  present: {const StudentId('s1')},
  sheetId: sheet == null ? null : SheetId(sheet),
);

SheetSuggestion? suggest({
  required int head,
  String block = 'coule',
  List<SessionRecord> given = const [],
  Map<SessionId, int>? attempts,
  Set<ExerciseRef> validatedByAll = const {},
  int today = 12,
  List<SessionSheet>? catalogueSheets,
}) => suggestSheet(
  mainBlockId: block,
  head: ref(block, head),
  sheets: catalogueSheets ?? sheets(),
  groupSessions: given,
  attemptCountBySession:
      attempts ?? {for (final session in given) session.id: 1},
  today: day(today),
  validatedByAll: validatedByAll,
);

void main() {
  Set<ExerciseRef> validated(String block, Iterable<int> numbers) => {
    for (final n in numbers) ref(block, n),
  };

  test('proposes the part holding the head when nothing was given', () {
    final result = suggest(head: 1)!;

    expect(result.option.id, SheetId('coule-1'));
    expect(result.kind, SheetSuggestionKind.coversHead);
    expect(result.headCovered, isTrue);
    expect(result.exerciseNumbers, [1, 2, 3]);
    expect(result.head, ref('coule', 1));
    expect(result.lastGivenOn, isNull);
  });

  test('proposes the second part when the head is 5', () {
    expect(suggest(head: 5)!.option.id, SheetId('coule-2'));
  });

  test('head decides over the first pending part (S1)', () {
    // coule-1 n'est pas « sans objet » (un élève ne l'a pas validé), mais la
    // tête (5) est dans coule-2.
    final result = suggest(head: 5, validatedByAll: validated('coule', [4]))!;

    expect(result.option.id, SheetId('coule-2'));
    expect(result.kind, SheetSuggestionKind.coversHead);
  });

  test('a given part holding the head leads to the next pending part', () {
    final result = suggest(head: 2, given: [record('x1', 'coule-1')])!;

    expect(result.option.id, SheetId('coule-2'));
    expect(result.kind, SheetSuggestionKind.nextPending);
    expect(result.headCovered, isFalse);
  });

  test('a skipped part is proposed again', () {
    final result = suggest(head: 1, given: [record('x1', 'coule-2')])!;

    expect(result.option.id, SheetId('coule-1'));
    expect(result.kind, SheetSuggestionKind.coversHead);
  });

  test('repeats the part holding the head once all are given (S4)', () {
    final result = suggest(
      head: 5,
      given: [
        record('x1', 'coule-1'),
        record('x2', 'coule-2', dayOfMonth: 5),
        record('x3', 'coule-3', dayOfMonth: 8),
      ],
    )!;

    expect(result.option.id, SheetId('coule-2'));
    expect(result.kind, SheetSuggestionKind.repeat);
    expect(result.lastGivenOn, day(5));
  });

  test('lastGivenOn is the most recent given session of the part', () {
    final result = suggest(
      head: 5,
      given: [
        record('x1', 'coule-1'),
        record('x2', 'coule-2', dayOfMonth: 9),
        record('x4', 'coule-2', dayOfMonth: 3),
        record('x3', 'coule-3'),
      ],
    )!;

    expect(result.lastGivenOn, day(9));
  });

  test('lastGivenOn ignores the time of day', () {
    final late = record(
      'x2',
      'coule-2',
    ).copyWith(date: DateTime(2026, 10, 5, 21, 30));

    final result = suggest(
      head: 5,
      given: [record('x1', 'coule-1'), late, record('x3', 'coule-3')],
    )!;

    expect(result.lastGivenOn, day(5));
  });

  test('skips a part every student validated (O)', () {
    final result = suggest(
      head: 5,
      given: [record('x1', 'coule-2')],
      validatedByAll: validated('coule', [1, 2, 3, 4]),
    )!;

    expect(result.option.id, SheetId('coule-3'));
    expect(result.kind, SheetSuggestionKind.nextPending);
  });

  test('a part holding the head is never without object', () {
    final result = suggest(
      head: 1,
      validatedByAll: validated('coule', [1, 2, 3]),
    )!;

    expect(result.option.id, SheetId('coule-1'));
  });

  test('an empty validatedByAll skips nothing', () {
    expect(suggest(head: 7)!.option.id, SheetId('coule-3'));
  });

  test('a session without sheet does not count (S2)', () {
    final result = suggest(head: 1, given: [record('x1', null)])!;

    expect(result.option.id, SheetId('coule-1'));
  });

  test('a session without passes does not count (S7)', () {
    final result = suggest(
      head: 1,
      given: [record('x1', 'coule-1')],
      attempts: {},
    )!;

    expect(result.option.id, SheetId('coule-1'));
    expect(result.kind, SheetSuggestionKind.coversHead);
  });

  test('a session dated after today does not count (S7)', () {
    final result = suggest(
      head: 1,
      given: [record('x1', 'coule-1', dayOfMonth: 13)],
    )!;

    expect(result.option.id, SheetId('coule-1'));
  });

  test('a session dated today counts (S7)', () {
    final result = suggest(
      head: 1,
      given: [record('x1', 'coule-1', dayOfMonth: 12)],
    )!;

    expect(result.option.id, SheetId('coule-2'));
  });

  test('an unknown sheet identifier is ignored', () {
    final result = suggest(head: 1, given: [record('x1', 'inconnue-9')])!;

    expect(result.option.id, SheetId('coule-1'));
  });

  test('a block without session proposes nothing (S8)', () {
    expect(suggest(block: 'quantites-de-billes', head: 1), isNull);
  });

  test('shared block: quart then finesse', () {
    expect(
      suggest(block: 'quart-finesses', head: 1)!.option.id,
      SheetId('quart-1'),
    );
    final next = suggest(
      block: 'quart-finesses',
      head: 3,
      given: [record('x1', 'quart-1')],
    )!;
    expect(next.option.id, SheetId('finesse-1'));
    expect(next.kind, SheetSuggestionKind.coversHead);
  });

  test('a head absent from every session proposes nothing once all given', () {
    final result = suggest(
      head: 9,
      given: [
        record('x1', 'coule-1'),
        record('x2', 'coule-2'),
        record('x3', 'coule-3'),
      ],
    );

    expect(result, isNull);
  });

  test('is independent of the order of the sheets and of the sessions', () {
    final result = suggest(
      head: 5,
      catalogueSheets: sheets().reversed.toList(),
      given: [record('x3', 'coule-3'), record('x1', 'coule-1')],
    )!;

    expect(result.option.id, SheetId('coule-2'));
  });

  group('validatedByAll', () {
    StudentProgress student(String id, Iterable<int> acquired) =>
        StudentProgress(
          studentId: StudentId(id),
          results: const {},
          acquiredExercises: validated('coule', acquired),
        );

    test('is empty without any student, never "everything"', () {
      expect(validatedByAll(const []), isEmpty);
    });

    test('keeps what every student validated', () {
      final result = validatedByAll([
        student('s1', [1, 2, 3]),
        student('s2', [2, 3, 4]),
      ]);

      expect(result, validated('coule', [2, 3]));
    });

    test('counts the exercises acquired at placement (lot 7)', () {
      final result = validatedByAll([
        student('s1', [1, 2]),
      ]);

      expect(result, validated('coule', [1, 2]));
    });
  });
}
