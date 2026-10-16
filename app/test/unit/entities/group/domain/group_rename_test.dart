import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  final group =
      Group(
        id: const GroupId('g'),
        seasonId: const SeasonId('s'),
        name: 'Jeunes',
        audience: Audience.children,
      ).admit(
        studentId: const StudentId('a'),
        studentAudience: Audience.children,
        from: day(1),
      );

  test('renames the group and keeps everything else', () {
    final renamed = group.rename('  Mercredi ');

    expect(renamed.name, 'Mercredi');
    expect(renamed.id, group.id);
    expect(renamed.audience, group.audience);
    expect(renamed.memberships, group.memberships);
  });

  test('refuses a blank name', () {
    expect(() => group.rename('  '), violation(InvariantCode.blankName));
  });
}
