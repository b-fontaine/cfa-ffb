import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

Group _group(
  String id, {
  String season = 'now',
  Audience audience = Audience.children,
}) => Group(
  id: GroupId(id),
  seasonId: SeasonId(season),
  name: id,
  audience: audience,
);

void main() {
  const now = SeasonId('now');

  Group? choose(
    List<Group> groups, {
    Audience audience = Audience.children,
    String? requested,
  }) => chooseGroup(
    groups: groups,
    seasonId: now,
    audience: audience,
    requested: requested == null ? null : GroupId(requested),
  );

  test('takes the only candidate when nothing is requested', () {
    final groups = [
      _group('past', season: 'old'),
      _group('adults', audience: Audience.adults),
      _group('kids'),
    ];

    expect(choose(groups)?.id, const GroupId('kids'));
  });

  test('returns null when no group fits, so that one is created', () {
    expect(choose([_group('adults', audience: Audience.adults)]), isNull);
    expect(choose(const []), isNull);
  });

  test('asks for a choice when several groups fit', () {
    expect(
      () => choose([_group('a'), _group('b')]),
      violation(InvariantCode.groupChoiceRequired),
    );
  });

  test('accepts the requested group among several', () {
    expect(
      choose([_group('a'), _group('b')], requested: 'b')?.id,
      const GroupId('b'),
    );
  });

  test('accepts the requested group even when it is the only one', () {
    expect(choose([_group('a')], requested: 'a')?.id, const GroupId('a'));
  });

  test('refuses a requested group of another season', () {
    expect(
      () =>
          choose([_group('a'), _group('old', season: 'old')], requested: 'old'),
      violation(InvariantCode.unknownGroup),
    );
  });

  test('refuses a requested group that does not exist', () {
    expect(
      () => choose([_group('a')], requested: 'ghost'),
      violation(InvariantCode.unknownGroup),
    );
  });

  test('refuses a requested group of another audience', () {
    expect(
      () => choose([
        _group('a'),
        _group('adults', audience: Audience.adults),
      ], requested: 'adults'),
      violation(InvariantCode.audienceMismatch),
    );
  });

  test('compares group names without case nor surrounding spaces', () {
    expect(normalizedGroupName('  Mercredi '), normalizedGroupName('mercredi'));
    expect(
      normalizedGroupName('Mercredi'),
      isNot(normalizedGroupName('Lundi')),
    );
  });
}
