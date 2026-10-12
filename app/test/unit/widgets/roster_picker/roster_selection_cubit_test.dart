import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/widgets/roster_picker/presentation/roster_selection_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/club_fixtures.dart';

void main() {
  final lea = summary('s1', 'Léa');
  final hugo = summary('s2', 'Hugo');
  final mia = summary('s3', 'Mia');
  final first = groupOverview('g1', 'First', [lea, hugo]);
  final second = groupOverview('g2', 'Second', [mia]);
  final groups = [first, second];

  group('resolution', () {
    test('defaults to the first group with everybody present', () {
      final selection = RosterSelectionCubit().state.resolve(groups)!;

      expect(selection.group, first);
      expect(selection.present, {lea.student.id, hugo.student.id});
    });

    test('starts on the requested group when it exists', () {
      final selection = RosterSelectionCubit(
        initialGroupId: const GroupId('g2'),
      ).state.resolve(groups)!;

      expect(selection.group, second);
      expect(selection.present, {mia.student.id});
    });

    test('falls back to the first group when the requested one is unknown', () {
      final selection = RosterSelectionCubit(
        initialGroupId: const GroupId('nope'),
      ).state.resolve(groups)!;

      expect(selection.group, first);
    });

    test('has no selection without groups', () {
      expect(RosterSelectionCubit().state.resolve(const []), isNull);
    });
  });

  blocTest<RosterSelectionCubit, RosterSelectionState>(
    'switching group selects it and resets absences',
    build: RosterSelectionCubit.new,
    act: (cubit) => cubit
      ..presenceChanged(lea.student.id, isPresent: false)
      ..groupSelected(const GroupId('g2')),
    expect: () => [
      RosterSelectionState(absent: {lea.student.id}),
      const RosterSelectionState(groupId: GroupId('g2')),
    ],
    verify: (cubit) {
      final selection = cubit.state.resolve(groups)!;
      expect(selection.group, second);
      expect(selection.present, {mia.student.id});
    },
  );

  blocTest<RosterSelectionCubit, RosterSelectionState>(
    'unchecking then checking a student toggles their presence',
    build: RosterSelectionCubit.new,
    act: (cubit) => cubit
      ..presenceChanged(lea.student.id, isPresent: false)
      ..presenceChanged(lea.student.id, isPresent: true),
    expect: () => [
      RosterSelectionState(absent: {lea.student.id}),
      const RosterSelectionState(),
    ],
  );

  test('an absent student is left out of the present set', () {
    final cubit = RosterSelectionCubit()
      ..presenceChanged(hugo.student.id, isPresent: false);

    expect(cubit.state.resolve(groups)!.present, {lea.student.id});
  });
}
