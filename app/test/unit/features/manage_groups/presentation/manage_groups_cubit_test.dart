import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/features/manage_groups/domain/create_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/delete_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/rename_group.dart';
import 'package:billard_cfa/features/manage_groups/presentation/bloc/manage_groups_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';

class _MockCreate extends Mock implements CreateGroup;

class _MockRename extends Mock implements RenameGroup;

class _MockDelete extends Mock implements DeleteGroup;

void main() {
  late _MockCreate create;
  late _MockRename rename;
  late _MockDelete delete;
  const season = SeasonId('s');
  const groupId = GroupId('g1');
  final group = Group(
    id: groupId,
    seasonId: season,
    name: 'Mercredi',
    audience: Audience.children,
  );

  setUp(() {
    create = _MockCreate();
    rename = _MockRename();
    delete = _MockDelete();
  });

  ManageGroupsCubit build() => ManageGroupsCubit(
    create,
    rename,
    delete,
    FixedClock(DateTime(2026, 10, 12, 9)),
  );

  blocTest<ManageGroupsCubit, ManageGroupsState>(
    'creates a group',
    build: () {
      when(
        () => create(
          seasonId: season,
          name: 'Mercredi',
          audience: Audience.children,
        ),
      ).thenAnswer((_) async => Ok(group));
      return build();
    },
    act: (cubit) => cubit.create(
      seasonId: season,
      name: 'Mercredi',
      audience: Audience.children,
    ),
    expect: () => const [
      ManageGroupsState(
        status: ManageGroupsStatus.working,
        action: ManageGroupsAction.create,
        name: 'Mercredi',
      ),
      ManageGroupsState(
        status: ManageGroupsStatus.done,
        action: ManageGroupsAction.create,
        name: 'Mercredi',
      ),
    ],
  );

  blocTest<ManageGroupsCubit, ManageGroupsState>(
    'reports a refused creation',
    build: () {
      when(
        () => create(
          seasonId: season,
          name: 'Mercredi',
          audience: Audience.children,
        ),
      ).thenAnswer(
        (_) async =>
            const Err(InvariantViolation(InvariantCode.groupNameTaken)),
      );
      return build();
    },
    act: (cubit) => cubit.create(
      seasonId: season,
      name: 'Mercredi',
      audience: Audience.children,
    ),
    expect: () => const [
      ManageGroupsState(
        status: ManageGroupsStatus.working,
        action: ManageGroupsAction.create,
        name: 'Mercredi',
      ),
      ManageGroupsState(
        status: ManageGroupsStatus.refused,
        action: ManageGroupsAction.create,
        name: 'Mercredi',
        failure: InvariantViolation(InvariantCode.groupNameTaken),
      ),
    ],
  );

  blocTest<ManageGroupsCubit, ManageGroupsState>(
    'renames a group',
    build: () {
      when(() => rename(groupId: groupId, name: 'Lundi'))
          .thenAnswer((_) async => Ok(group.rename('Lundi')));
      return build();
    },
    act: (cubit) => cubit.rename(groupId: groupId, name: 'Lundi'),
    expect: () => const [
      ManageGroupsState(
        status: ManageGroupsStatus.working,
        action: ManageGroupsAction.rename,
        name: 'Lundi',
      ),
      ManageGroupsState(
        status: ManageGroupsStatus.done,
        action: ManageGroupsAction.rename,
        name: 'Lundi',
      ),
    ],
  );

  blocTest<ManageGroupsCubit, ManageGroupsState>(
    'deletes a group as of today and reports a refusal',
    build: () {
      when(() => delete(groupId: groupId, today: DateTime(2026, 10, 12)))
          .thenAnswer(
            (_) async =>
                const Err(InvariantViolation(InvariantCode.groupNotEmpty)),
          );
      return build();
    },
    act: (cubit) => cubit.delete(groupId: groupId, name: 'Mercredi'),
    expect: () => const [
      ManageGroupsState(
        status: ManageGroupsStatus.working,
        action: ManageGroupsAction.delete,
        name: 'Mercredi',
      ),
      ManageGroupsState(
        status: ManageGroupsStatus.refused,
        action: ManageGroupsAction.delete,
        name: 'Mercredi',
        failure: InvariantViolation(InvariantCode.groupNotEmpty),
      ),
    ],
  );
}
