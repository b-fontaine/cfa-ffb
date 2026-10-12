import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed identifiers expose their value and compare by value', () {
    final raw = 'id-${DateTime.now().year > 0 ? 1 : 0}';

    expect(StudentId(raw).value, 'id-1');
    expect(StudentId(raw), const StudentId('id-1'));
    expect({GroupId(raw), const GroupId('id-1')}, hasLength(1));
    expect(SeasonId(raw).value, raw);
    expect(SessionId(raw).value, raw);
    expect(AttemptId(raw).value, raw);
    expect(AssessmentId(raw).value, raw);
  });
}
