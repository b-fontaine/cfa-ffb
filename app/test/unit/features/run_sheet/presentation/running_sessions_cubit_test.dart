import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_sessions_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/run_sheet_world.dart';

void main() {
  late RunSheetSessions sessions;
  late RunningSessionsCubit cubit;
  final key = RunKey(
    sheetId: SheetId('demi-bille-1'),
    audience: Audience.children,
  );

  setUp(() async {
    final world = RunSheetWorld();
    sessions = RunSheetSessions(world.resolve, world.ticker, world.keeper);
    final guide = sessions.of(key);
    await guide.load();
    guide.showStep(2);
    cubit = RunningSessionsCubit(sessions);
  });

  tearDown(() async {
    await cubit.close();
    await sessions.dispose();
  });

  test('starts empty and reads the registry on refresh', () {
    expect(cubit.state, isEmpty);

    cubit.refresh();

    expect(cubit.state.single.key, key);
    expect(cubit.state.single.step, 2);
  });

  test('abandon releases the guide and leaves the list', () async {
    cubit.refresh();

    await cubit.abandon(key);

    expect(cubit.state, isEmpty);
    expect(sessions.runningKeys, isEmpty);
  });

  test('abandon of an unknown guide changes nothing', () async {
    cubit.refresh();

    await cubit.abandon(RunKey(sheetId: SheetId('quart-1')));

    expect(cubit.state, hasLength(1));
    expect(sessions.runningKeys, [key]);
  });
}
