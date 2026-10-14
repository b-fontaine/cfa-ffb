import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/session_range.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/recorded_session_list.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

RecordedSessionSummary _summary({
  String id = 'x1',
  int dayOfMonth = 12,
  Set<StudentId> present = const {StudentId('s1')},
  Audience audience = Audience.children,
  TrainingBlock? mainBlock,
  int attemptCount = 2,
  SheetOption? sheet,
}) => RecordedSessionSummary(
  session: SessionRecord(
    id: SessionId(id),
    groupId: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    date: day(dayOfMonth),
    audience: audience,
    present: present,
    mainBlockId: mainBlock?.id,
  ),
  groupName: 'Jeunes',
  mainBlock: mainBlock,
  attemptCount: attemptCount,
  sheet: sheet,
);

/// Bloc proposé `[Prop]` : le bloc et ses exercices portent la même source.
final _proposal = TrainingBlock(
  id: 'p',
  title: 'Bloc p',
  teachingOrder: 1,
  recommendedSessions: SessionRange(min: 1, max: 2),
  technicalSheets: const [1],
  exercises: [
    ExerciseSpec(ref: ref('p', 1), rate: rate(), source: Provenance.prop),
  ],
  source: Provenance.prop,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<RecordedSessionSummary> sessions, {
    ValueChanged<SessionId>? onOpenSession,
  }) => pumpUi(
    tester,
    SingleChildScrollView(
      child: RecordedSessionList(
        sessions: sessions,
        onOpenSession: onOpenSession ?? (_) {},
      ),
    ),
  );

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(RecordedSessionList)));

  testWidgets('says when nothing was recorded', (tester) async {
    await pump(tester, const []);

    expect(find.text('No session recorded yet.'), findsOneWidget);
  });

  testWidgets('describes a session: date, group, audience, counts', (
    tester,
  ) async {
    await pump(tester, [_summary()]);

    expect(find.textContaining('Oct 12'), findsOneWidget);
    expect(find.text('Jeunes · Children'), findsOneWidget);
    expect(find.text('1 present'), findsOneWidget);
    expect(find.text('2 passes'), findsOneWidget);
    expect(find.textContaining('Main notion'), findsNothing);
  });

  testWidgets('names the main block of the session', (tester) async {
    await pump(tester, [_summary(mainBlock: block('a', 1))]);

    expect(find.text(l10nOf(tester).recordBlockHint('Bloc a')), findsOneWidget);
  });

  testWidgets('names the catalogue session over the main block', (
    tester,
  ) async {
    await pump(tester, [
      _summary(
        mainBlock: block('a', 1),
        sheet: SheetOption(
          id: SheetId('demi-bille-2'),
          technique: 'demi-bille',
          techniqueRank: 2,
          title: 'Quantité demi-bille',
          part: 2,
          partCount: 2,
        ),
      ),
    ]);

    expect(
      find.text('Catalogue session: Quantité demi-bille, session 2/2'),
      findsOneWidget,
    );
    expect(find.textContaining('Main notion'), findsNothing);
  });

  testWidgets('tags a proposed block as a proposal', (tester) async {
    await pump(tester, [_summary(mainBlock: _proposal)]);

    final l10n = l10nOf(tester);
    expect(
      find.text(l10n.proposalTagged(l10n.recordBlockHint('Bloc p'))),
      findsOneWidget,
    );
  });

  testWidgets('uses the singular and the empty forms', (tester) async {
    await pump(tester, [
      _summary(present: const {}, attemptCount: 1, audience: Audience.adults),
    ]);

    expect(find.text('Nobody present'), findsOneWidget);
    expect(find.text('1 pass'), findsOneWidget);
    expect(find.text('Jeunes · Adults'), findsOneWidget);
  });

  testWidgets('each row is a labelled button that opens the session', (
    tester,
  ) async {
    SessionId? opened;
    await pump(tester, [_summary()], onOpenSession: (id) => opened = id);

    final label = l10nOf(tester).historyOpen(
      MaterialLocalizations.of(tester.element(find.byType(RecordedSessionList)))
          .formatMediumDate(day(12)),
      'Jeunes',
    );
    expect(find.bySemanticsLabel(label), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(label));

    expect(opened, const SessionId('x1'));
  });
}
