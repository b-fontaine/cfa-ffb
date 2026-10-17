import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

RunProgressKey _key({
  String sheet = 'demi-bille-1',
  Audience? audience = Audience.children,
  String? session,
  String? group,
}) => RunProgressKey(
  sheetId: SheetId(sheet),
  audience: audience,
  sessionId: session,
  groupId: group == null ? null : GroupId(group),
);

RunProgress _progress({
  int step = 0,
  Map<String, int> counts = const {},
  Map<String, Set<int>> checked = const {},
  int scoreA = 0,
  int scoreB = 0,
  int timerSeconds = 0,
}) => RunProgress(
  key: _key(),
  step: step,
  counts: counts,
  checked: checked,
  scoreA: scoreA,
  scoreB: scoreB,
  timerSeconds: timerSeconds,
  updatedAt: DateTime.utc(2026, 10, 16, 9),
);

InvariantCode _violation(void Function() build) {
  try {
    build();
  } on InvariantViolation catch (violation) {
    return violation.code;
  }
  fail('aucune violation levée');
}

void main() {
  group('RunProgressKey.encoded', () {
    test('is stable and readable for a plain key', () {
      expect(
        _key(session: 'p1', group: 'g1').encoded,
        'demi-bille-1|children|v:p1|v:g1',
      );
    });

    test('tells apart every field, a missing one included', () {
      final keys = [
        _key(),
        _key(audience: null),
        _key(audience: Audience.adults),
        _key(session: 'p1'),
        _key(group: 'g1'),
        _key(sheet: 'demi-bille-2'),
        _key(session: ''),
      ];

      expect({for (final key in keys) key.encoded}, hasLength(keys.length));
    });

    test('escapes the separator so two keys never collide', () {
      final first = _key(session: 'a|b');
      final second = _key(session: 'a', group: 'b');

      expect(first.encoded, isNot(second.encoded));
      expect(first.encoded.split('|'), hasLength(4));
    });

    test('equal keys have the same text', () {
      expect(_key(session: 'p1').encoded, _key(session: 'p1').encoded);
      expect(_key(session: 'p1'), _key(session: 'p1'));
    });
  });

  group('RunProgress invariants', () {
    test('accepts a progress with all fields', () {
      final progress = _progress(
        step: 4,
        counts: {'ini': 2},
        checked: {
          'grille': {0, 2},
        },
        scoreA: 3,
        scoreB: 999,
        timerSeconds: 42,
      );

      expect(progress.step, 4);
      expect(progress.scoreB, 999);
    });

    test('rejects a negative step', () {
      expect(_violation(() => _progress(step: -1)), InvariantCode.invalidRange);
    });

    test('rejects a negative timer', () {
      expect(
        _violation(() => _progress(timerSeconds: -1)),
        InvariantCode.invalidRange,
      );
    });

    test('rejects a negative counter and an empty initiation id', () {
      expect(
        _violation(() => _progress(counts: {'ini': -1})),
        InvariantCode.invalidRange,
      );
      expect(
        _violation(() => _progress(counts: {'': 1})),
        InvariantCode.invalidRange,
      );
    });

    test('rejects a negative criterion index and an empty id in the grid', () {
      expect(
        _violation(
          () => _progress(
            checked: {
              'grille': {-1},
            },
          ),
        ),
        InvariantCode.invalidRange,
      );
      expect(
        _violation(
          () => _progress(
            checked: {
              '': {0},
            },
          ),
        ),
        InvariantCode.invalidRange,
      );
    });

    test('accepts the bounds of the score and the zero step and timer', () {
      for (final score in [0, 999]) {
        expect(_progress(scoreA: score).scoreA, score);
        expect(_progress(scoreB: score).scoreB, score);
      }
      expect(_progress().step, 0);
      expect(_progress().timerSeconds, 0);
    });

    test('rejects a score just outside 0..999 on each side', () {
      for (final score in [-1, 1000]) {
        expect(
          _violation(() => _progress(scoreA: score)),
          InvariantCode.scoreOutOfRange,
        );
        expect(
          _violation(() => _progress(scoreB: score)),
          InvariantCode.scoreOutOfRange,
        );
      }
    });

    test('rejects a score outside 0..999', () {
      expect(
        _violation(() => _progress(scoreA: -1)),
        InvariantCode.scoreOutOfRange,
      );
      expect(
        _violation(() => _progress(scoreB: 1000)),
        InvariantCode.scoreOutOfRange,
      );
    });
  });
}
