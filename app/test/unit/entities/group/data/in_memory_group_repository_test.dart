import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores and finds a group', () async {
    final repository = InMemoryGroupRepository();
    final group = Group(
      id: const GroupId('g1'),
      seasonId: const SeasonId('s1'),
      name: 'Jeunes',
      audience: Audience.children,
    );

    expect(await repository.byId(const GroupId('g1')), isNull);
    await repository.save(group);

    expect(await repository.byId(const GroupId('g1')), group);
  });
}
