import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/run_sheet_world.dart';

void main() {
  late RunSheetWorld world;
  late RunSheetSessions sessions;

  RunKey key(String sheet, {String? sessionId, GroupId? group}) => RunKey(
    sheetId: SheetId(sheet),
    audience: Audience.children,
    sessionId: sessionId,
    group: group,
  );

  /// Ouvre le guide de [key], le charge et va à [step].
  Future<void> start(RunKey key, {int step = 0}) async {
    final cubit = sessions.of(key);
    await cubit.load();
    cubit.showStep(step);
  }

  setUp(() {
    world = RunSheetWorld();
    sessions = RunSheetSessions(world.resolve, world.ticker);
  });

  test('is empty when no guide is open', () {
    expect(sessions.snapshot(), isEmpty);
  });

  test('ignores a guide without progress', () async {
    await start(key('demi-bille-1'));

    expect(sessions.snapshot(), isEmpty);
  });

  test('ignores a guide that is still loading', () {
    sessions.of(key('demi-bille-1'));

    expect(sessions.snapshot(), isEmpty);
  });

  test('ignores a guide where only the timer was started', () async {
    await start(key('demi-bille-1'));
    sessions.of(key('demi-bille-1')).timerToggled();

    expect(sessions.snapshot(), isEmpty);
  });

  test('lists a guide with progress and what it needs to be resumed', () async {
    await world.sessions.add(
      Session(
        id: 'p1',
        title: 'Séance',
        date: day(19),
        audience: Audience.children,
        groupId: const GroupId('g1'),
        sheetId: SheetId('demi-bille-1'),
      ),
    );
    await start(key('demi-bille-1', sessionId: 'p1'), step: 2);

    final running = sessions.snapshot().single;

    expect(running.key, key('demi-bille-1', sessionId: 'p1'));
    expect(running.step, 2);
    expect(running.stepCount, greaterThan(2));
    expect(running.sheetTitle, isNotEmpty);
    expect(running.part, 1);
    expect(running.partCount, 2);
    expect(running.plannedGroupId, const GroupId('g1'));
    expect(running.plannedDate, day(19));
    expect(
      running.phase,
      sessions
          .of(key('demi-bille-1', sessionId: 'p1'))
          .state
          .currentStep!
          .phase,
    );
  });

  test('has no planned group for a guide started from the catalogue', () async {
    await start(key('demi-bille-1'), step: 1);

    final running = sessions.snapshot().single;

    expect(running.plannedGroupId, isNull);
    expect(running.plannedDate, isNull);
  });

  test('lists the most recently used first', () async {
    await start(key('demi-bille-1'), step: 1);
    await start(key('demi-bille-2'), step: 1);
    sessions.of(key('demi-bille-1'));

    expect(
      [for (final r in sessions.snapshot()) r.key.sheetId.value],
      ['demi-bille-1', 'demi-bille-2'],
    );
  });

  test('does not change the order of use nor create guides', () async {
    await start(key('demi-bille-1'), step: 1);
    await start(key('demi-bille-2'), step: 1);
    final before = sessions.runningKeys;

    sessions.snapshot();

    expect(sessions.runningKeys, before);
  });

  test('forgets a released guide and an evicted one', () async {
    await start(key('demi-bille-1'), step: 1);
    await start(key('demi-bille-2'), step: 1);
    await sessions.release(key('demi-bille-1'));

    expect(
      [for (final r in sessions.snapshot()) r.key.sheetId.value],
      ['demi-bille-2'],
    );
  });
}
