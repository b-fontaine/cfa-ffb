import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupChoice', () {
    test('is equal by identifier and name, with the same hash code', () {
      const a = GroupChoice(GroupId('g1'), 'Enfants');
      const b = GroupChoice(GroupId('g1'), 'Enfants');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs by name or by identifier', () {
      const a = GroupChoice(GroupId('g1'), 'Enfants');

      expect(a, isNot(const GroupChoice(GroupId('g1'), 'Adultes')));
      expect(a, isNot(const GroupChoice(GroupId('g2'), 'Enfants')));
    });
  });
}
