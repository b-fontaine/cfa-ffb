import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session.duration', () {
    test('lasts 90 minutes for children', () {
      const session = Session(id: '1', title: 't', audience: Audience.children);

      expect(session.duration, const Duration(minutes: 90));
    });

    test('lasts 120 minutes for adults', () {
      const session = Session(id: '1', title: 't', audience: Audience.adults);

      expect(session.duration, const Duration(minutes: 120));
    });
  });

  test('sessions with the same fields are equal', () {
    const a = Session(id: '1', title: 't', audience: Audience.adults);
    const b = Session(id: '1', title: 't', audience: Audience.adults);

    expect(a, b);
    expect(a.copyWith(title: 'autre'), isNot(a));
  });
}
