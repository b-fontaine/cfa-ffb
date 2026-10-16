import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/suggest_session/domain/given_sheets.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

SessionRecord record(String id, String? sheet, {int dayOfMonth = 1}) =>
    SessionRecord(
      id: SessionId(id),
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      date: day(dayOfMonth),
      audience: Audience.children,
      present: {const StudentId('s1')},
      sheetId: sheet == null ? null : SheetId(sheet),
    );

void main() {
  Map<SheetId, DateTime> given(
    List<SessionRecord> sessions, {
    Map<SessionId, int>? attempts,
    int today = 12,
  }) => givenSheets(
    groupSessions: sessions,
    attemptCountBySession: attempts ?? {for (final s in sessions) s.id: 1},
    today: day(today),
  );

  test('a session with a catalogue sheet and a pass is given', () {
    final result = given([record('r1', 'coule-1', dayOfMonth: 3)]);

    expect(result, {SheetId('coule-1'): day(3)});
  });

  test('a session without a catalogue sheet is ignored', () {
    expect(given([record('r1', null)]), isEmpty);
  });

  test('a session without any pass is ignored', () {
    final r = record('r1', 'coule-1');

    expect(given([r], attempts: {r.id: 0}), isEmpty);
    expect(given([r], attempts: const {}), isEmpty);
  });

  test('a session dated after today is ignored, today itself counts', () {
    expect(given([record('r1', 'coule-1', dayOfMonth: 13)]), isEmpty);
    expect(given([record('r1', 'coule-1', dayOfMonth: 12)]), isNotEmpty);
  });

  test('keeps the most recent date when a sheet was given twice', () {
    final result = given([
      record('r1', 'coule-1', dayOfMonth: 5),
      record('r2', 'coule-1', dayOfMonth: 9),
      record('r3', 'coule-1', dayOfMonth: 2),
    ]);

    expect(result[SheetId('coule-1')], day(9));
  });
}
