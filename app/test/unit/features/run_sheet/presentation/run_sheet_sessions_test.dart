import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/run_progress_support.dart';

class _MockResolve extends Mock implements ResolveRunPlan;

void main() {
  late RunSheetSessions sessions;
  final key = RunKey(sheetId: SheetId('demi-bille-1'));

  setUp(
    () => sessions = RunSheetSessions(
      _MockResolve(),
      PeriodicRunTicker(),
      inMemoryRunProgressKeeper(),
    ),
  );

  test('keeps one cubit per key', () {
    expect(sessions.of(key), same(sessions.of(key)));
  });

  test(
    'tells the keys apart by session, audience, planned session and group',
    () {
      final other = [
        RunKey(sheetId: SheetId('demi-bille-2')),
        RunKey(sheetId: SheetId('demi-bille-1'), audience: Audience.adults),
        RunKey(sheetId: SheetId('demi-bille-1'), sessionId: 'p1'),
        RunKey(sheetId: SheetId('demi-bille-1'), group: const GroupId('g1')),
      ];

      for (final k in other) {
        expect(sessions.of(k), isNot(same(sessions.of(key))));
        expect(k, isNot(key));
      }
      expect(RunKey(sheetId: SheetId('demi-bille-1')), key);
      expect(RunKey(sheetId: SheetId('demi-bille-1')).hashCode, key.hashCode);
    },
  );

  test('release closes the cubit and forgets it', () async {
    final cubit = sessions.of(key);

    await sessions.release(key);

    expect(cubit.isClosed, isTrue);
    expect(sessions.runningKeys, isEmpty);
    expect(sessions.of(key), isNot(same(cubit)));
  });

  test('release of an unknown key does nothing', () async {
    final cubit = sessions.of(key);

    await sessions.release(RunKey(sheetId: SheetId('quart-1')));

    expect(cubit.isClosed, isFalse);
    expect(sessions.runningKeys, [key]);
  });

  test('keeps at most maxRunning sessions and evicts the oldest', () async {
    final keys = [
      for (var i = 1; i <= RunSheetSessions.maxRunning + 1; i++)
        RunKey(sheetId: SheetId('technique-$i')),
    ];
    final first = sessions.of(keys.first);

    keys.skip(1).forEach(sessions.of);

    await Future<void>.delayed(Duration.zero);

    expect(sessions.runningKeys, keys.skip(1));
    expect(first.isClosed, isTrue);
  });

  test('a session used again becomes the most recent one', () {
    final keys = [
      for (var i = 1; i <= RunSheetSessions.maxRunning; i++)
        RunKey(sheetId: SheetId('technique-$i')),
    ];
    final cubits = keys.map(sessions.of).toList();
    final reused = sessions.of(keys.first);
    final other = RunKey(sheetId: SheetId('autre-1'));
    expect(sessions.of(other), isNot(same(reused)));
    expect(reused, same(cubits.first));

    expect(sessions.runningKeys, contains(keys.first));
    expect(sessions.runningKeys, isNot(contains(keys[1])));
    expect(reused.isClosed, isFalse);
  });

  test('closes every cubit when disposed', () async {
    final cubit = sessions.of(key);

    await sessions.dispose();

    expect(cubit.isClosed, isTrue);
    expect(sessions.of(key), isNot(same(cubit)));
  });
}
