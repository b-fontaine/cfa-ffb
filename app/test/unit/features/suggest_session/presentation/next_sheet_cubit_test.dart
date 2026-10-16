import 'package:billard_cfa/features/suggest_session/domain/next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/next_sheet_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSuggest extends Mock implements SuggestNextSheet;

void main() {
  late _MockSuggest suggest;
  const group = GroupId('g1');
  const present = {StudentId('s1'), StudentId('s2')};
  const next = NextSheet(audience: Audience.children, mainBlockId: 'posture');

  setUp(() => suggest = _MockSuggest());

  blocTest<NextSheetCubit, NextSheetState>(
    'loads the next sheet for the group and the present students',
    setUp: () =>
        when(() => suggest(groupId: group, present: present))
            .thenAnswer((_) async => const Ok(next)),
    build: () => NextSheetCubit(suggest),
    act: (cubit) => cubit.load(groupId: group, present: present),
    expect: () => [
      const NextSheetState(status: NextSheetStatus.ready, next: next),
    ],
  );

  blocTest<NextSheetCubit, NextSheetState>(
    'reports a failure',
    setUp: () => when(() => suggest(groupId: group, present: present))
        .thenAnswer((_) async => const Err<NextSheet>(NotFound('group', 'g1'))),
    build: () => NextSheetCubit(suggest),
    act: (cubit) => cubit.load(groupId: group, present: present),
    expect: () => [
      const NextSheetState(
        status: NextSheetStatus.failure,
        failure: NotFound('group', 'g1'),
      ),
    ],
  );
}
