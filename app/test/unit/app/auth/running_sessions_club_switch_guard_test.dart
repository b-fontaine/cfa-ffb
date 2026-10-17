import 'package:billard_cfa/app/auth/running_sessions_club_switch_guard.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessions extends Mock implements RunSheetSessions;

void main() {
  test('is free when no guided session is under way', () {
    final sessions = _MockSessions();
    when(sessions.snapshot).thenReturn(const <RunningSession>[]);

    expect(RunningSessionsClubSwitchGuard(sessions).isBlocked, isFalse);
  });

  test('is blocked as soon as one guided session has progress', () {
    final sessions = _MockSessions();
    when(sessions.snapshot).thenReturn([_Running()]);

    expect(RunningSessionsClubSwitchGuard(sessions).isBlocked, isTrue);
  });
}

class _Running extends Fake implements RunningSession;
