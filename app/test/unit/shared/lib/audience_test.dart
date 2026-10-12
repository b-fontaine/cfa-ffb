import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('children sessions last 90 minutes, adults sessions 120', () {
    expect(Audience.children.sessionDuration, const Duration(minutes: 90));
    expect(Audience.adults.sessionDuration, const Duration(minutes: 120));
  });
}
