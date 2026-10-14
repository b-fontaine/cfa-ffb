import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

Session _session({Audience audience = Audience.adults, String title = 't'}) =>
    Session(id: '1', title: title, date: day(12), audience: audience);

void main() {
  group('Session.duration', () {
    test('lasts 90 minutes for children', () {
      expect(
        _session(audience: Audience.children).duration,
        const Duration(minutes: 90),
      );
    });

    test('lasts 120 minutes for adults', () {
      expect(_session().duration, const Duration(minutes: 120));
    });
  });

  test('sessions with the same fields are equal', () {
    expect(_session(), _session());
    expect(_session().copyWith(title: 'autre'), isNot(_session()));
    expect(_session().copyWith(date: day(13)), isNot(_session()));
  });

  test('a session is free until it follows a catalogue session', () {
    final linked = _session().copyWith(sheetId: SheetId('demi-bille-2'));

    expect(_session().sheetId, isNull);
    expect(linked.sheetId?.value, 'demi-bille-2');
    expect(linked.copyWith(sheetId: null).sheetId, isNull);
  });

  test('a session may be planned for a group or without one', () {
    final forGroup = _session().copyWith(groupId: const GroupId('g1'));

    expect(_session().groupId, isNull);
    expect(forGroup.groupId, const GroupId('g1'));
    expect(forGroup.date, day(12));
  });
}
