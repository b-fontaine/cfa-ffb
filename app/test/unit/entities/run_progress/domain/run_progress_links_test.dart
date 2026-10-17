import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_links.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

RunProgressKey _key({String? session, String? group}) => RunProgressKey(
  sheetId: SheetId('demi-bille-1'),
  sessionId: session,
  groupId: group == null ? null : GroupId(group),
);

void main() {
  const links = RunProgressLinks(
    groups: {GroupId('g1')},
    records: {SessionId('x1')},
    plannedSessions: {'p1'},
  );

  test('touches a guide by its group, its planned session or its record', () {
    expect(links.touches(_key(group: 'g1')), isTrue);
    expect(links.touches(_key(session: 'p1')), isTrue);
    expect(links.touches(_key(), recordId: const SessionId('x1')), isTrue);
  });

  test('does not touch an unrelated guide', () {
    expect(links.touches(_key(group: 'g2', session: 'p2')), isFalse);
    expect(links.touches(_key(), recordId: const SessionId('x2')), isFalse);
    expect(links.touches(_key()), isFalse);
  });

  test('is empty only without any link', () {
    expect(const RunProgressLinks().isEmpty, isTrue);
    expect(links.isEmpty, isFalse);
    expect(const RunProgressLinks(groups: {GroupId('g')}).isEmpty, isFalse);
    expect(const RunProgressLinks(records: {SessionId('x')}).isEmpty, isFalse);
    expect(const RunProgressLinks(plannedSessions: {'p'}).isEmpty, isFalse);
  });
}
