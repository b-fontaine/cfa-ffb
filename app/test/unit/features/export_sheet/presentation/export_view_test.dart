import 'package:billard_cfa/features/export_sheet/domain/export_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/presentation/bloc/export_sheet_cubit.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/export_view.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_preview_view.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

ExportedDocument _exported({int pages = 3}) => ExportedDocument(
  document: PrintDocument(
    title: 'Titre',
    language: 'fr',
    pages: [
      for (var i = 0; i < pages; i++)
        PrintPage(
          width: 100,
          height: 140,
          items: [PrintText(x: 5, y: 10, text: 'Page $i', size: 8)],
        ),
    ],
  ),
  bytes: const [1, 2, 3],
  fileName: 'x.pdf',
);

class _Calls {
  final kinds = <ExportKind>[];
  final audiences = <Audience>[];
  final groups = <GroupId?>[];
  final names = <bool>[];
  final pages = <int>[];
  int saves = 0;
  int prints = 0;
}

void main() {
  const mardi = GroupChoice(GroupId('g1'), 'Mardi');

  Future<_Calls> pump(
    WidgetTester tester, {
    ExportSheetState? state,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = _Calls();
    await pumpUi(
      tester,
      SingleChildScrollView(
        child: ExportView(
          state:
              state ??
              ExportSheetState(
                status: ExportStatus.ready,
                exported: _exported(),
                groups: const [mardi],
                canPrint: true,
              ),
          onKindChanged: calls.kinds.add,
          onAudienceChanged: calls.audiences.add,
          onGroupChanged: calls.groups.add,
          onNamesChanged: calls.names.add,
          onPageChanged: calls.pages.add,
          onSave: () => calls.saves++,
          onPrint: () => calls.prints++,
        ),
      ),
      locale: locale,
    );
    return calls;
  }

  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(
        find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
      );

  group('document and audience', () {
    testWidgets('selects the animator sheet and the children by default', (
      tester,
    ) async {
      await pump(tester);

      expect(chip(tester, 'Animator sheet').selected, isTrue);
      expect(chip(tester, 'Results sheets').selected, isFalse);
      expect(chip(tester, 'Children · 90 min').selected, isTrue);
      expect(chip(tester, 'Adults · 120 min').selected, isFalse);
    });

    testWidgets('reports the choice of the document and of the audience', (
      tester,
    ) async {
      final calls = await pump(tester);

      await tester.tap(find.text('Results sheets'));
      await tester.tap(find.text('Adults · 120 min'));

      expect(calls.kinds, [ExportKind.results]);
      expect(calls.audiences, [Audience.adults]);
    });

    testWidgets('says what each document holds', (tester) async {
      await pump(tester);
      expect(find.textContaining('without any student name'), findsOneWidget);

      await pump(
        tester,
        state: ExportSheetState(
          status: ExportStatus.ready,
          kind: ExportKind.results,
          exported: _exported(),
        ),
      );
      expect(find.textContaining('four grids per page'), findsOneWidget);
      expect(find.textContaining('without any student name'), findsNothing);
    });

    testWidgets('is written in French for a French interface', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Feuille de l’animateur'), findsOneWidget);
      expect(find.text('Enfants · 90 min'), findsOneWidget);
      expect(find.text('Enregistrer le PDF'), findsOneWidget);
    });
  });

  group('group and first names', () {
    ExportSheetState results({GroupId? groupId, bool includeNames = false}) =>
        ExportSheetState(
          status: ExportStatus.ready,
          kind: ExportKind.results,
          exported: _exported(),
          groups: const [mardi],
          groupId: groupId,
          includeNames: includeNames,
        );

    testWidgets('is offered for the results sheets only', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('export-group')), findsNothing);

      await pump(tester, state: results());
      expect(find.byKey(const ValueKey('export-group')), findsOneWidget);
    });

    testWidgets('lists no group, then the groups, and reports the choice', (
      tester,
    ) async {
      final calls = await pump(tester, state: results());

      await tester.tap(find.byKey(const ValueKey('export-group')));
      await tester.pumpAndSettle();
      expect(find.text('No group, blank names'), findsWidgets);
      await tester.tap(find.text('Mardi').last);
      await tester.pumpAndSettle();

      expect(calls.groups, [const GroupId('g1')]);
    });

    testWidgets('keeps the names switch off until a group is chosen', (
      tester,
    ) async {
      await pump(tester, state: results());

      final off = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('export-names')),
      );
      expect(off.onChanged, isNull);

      await pump(tester, state: results(groupId: mardi.id));
      final on = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('export-names')),
      );
      expect(on.onChanged, isNotNull);
    });

    testWidgets('says in text when the groups could not be listed', (
      tester,
    ) async {
      await pump(tester, state: results());
      expect(find.textContaining('could not be listed'), findsNothing);

      await pump(
        tester,
        state: results().copyWith(groupsFailure: const NotFound('group', 'x')),
      );
      expect(find.textContaining('could not be listed'), findsOneWidget);
    });

    testWidgets('reports the request for names', (tester) async {
      final calls = await pump(tester, state: results(groupId: mardi.id));

      await tester.tap(find.text('Print the group’s first names'));

      expect(calls.names, [true]);
    });

    testWidgets('warns about the file only when the names are requested', (
      tester,
    ) async {
      await pump(tester, state: results(groupId: mardi.id));
      expect(find.textContaining('will contain first names'), findsNothing);

      await pump(tester, state: results(groupId: mardi.id, includeNames: true));
      expect(find.textContaining('will contain first names'), findsOneWidget);
      expect(find.textContaining('not erased'), findsOneWidget);
    });
  });

  group('preview', () {
    testWidgets('shows the first page and the page counter', (tester) async {
      await pump(tester);

      expect(find.byKey(printPreviewKey), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);
    });

    testWidgets('goes from page to page, within the document', (tester) async {
      final calls = await pump(
        tester,
        state: ExportSheetState(
          status: ExportStatus.ready,
          exported: _exported(),
          page: 1,
        ),
      );

      await tester.tap(find.byTooltip('Next page'));
      await tester.tap(find.byTooltip('Previous page'));

      expect(calls.pages, [2, 0]);
    });

    testWidgets('disables the arrows at both ends', (tester) async {
      await pump(tester);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNotNull,
      );

      await pump(
        tester,
        state: ExportSheetState(
          status: ExportStatus.ready,
          exported: _exported(),
          page: 2,
        ),
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('says the PDF is being prepared, and keeps the previous page', (
      tester,
    ) async {
      await pump(
        tester,
        state: ExportSheetState(
          status: ExportStatus.ready,
          exported: _exported(),
          preparing: true,
        ),
      );

      expect(find.text('Preparing the PDF…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(printPreviewKey), findsOneWidget);
    });

    testWidgets('says nothing about preparing once the document is ready', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Preparing the PDF…'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows no page before the first document', (tester) async {
      await pump(
        tester,
        state: const ExportSheetState(
          status: ExportStatus.ready,
          preparing: true,
        ),
      );

      expect(find.byKey(printPreviewKey), findsNothing);
      expect(find.byTooltip('Next page'), findsNothing);
    });
  });

  group('save and print', () {
    testWidgets('saves and prints', (tester) async {
      final calls = await pump(tester);

      await tester.tap(find.text('Save PDF'));
      await tester.tap(find.text('Print'));

      expect(calls.saves, 1);
      expect(calls.prints, 1);
    });

    testWidgets('hides printing where the platform cannot print', (
      tester,
    ) async {
      await pump(
        tester,
        state: ExportSheetState(
          status: ExportStatus.ready,
          exported: _exported(),
        ),
      );

      expect(find.text('Save PDF'), findsOneWidget);
      expect(find.text('Print'), findsNothing);
    });

    testWidgets('disables both while there is no document', (tester) async {
      await pump(
        tester,
        state: const ExportSheetState(
          status: ExportStatus.ready,
          preparing: true,
          canPrint: true,
        ),
      );

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('says in text what happened to the request', (tester) async {
      final texts = <ExportOutcome, String?>{
        ExportOutcome.none: null,
        ExportOutcome.saved: 'PDF saved.',
        ExportOutcome.cancelled: 'Save cancelled.',
        ExportOutcome.saveFailed: 'The PDF could not be saved.',
        ExportOutcome.printed: 'Sent to the printer.',
        ExportOutcome.printFailed: 'The PDF could not be sent to the printer.',
      };
      for (final entry in texts.entries) {
        await pump(
          tester,
          state: ExportSheetState(
            status: ExportStatus.ready,
            exported: _exported(),
            outcome: entry.key,
          ),
        );
        for (final text in texts.values.whereType<String>()) {
          expect(
            find.text(text),
            entry.value == text ? findsOneWidget : findsNothing,
            reason: '${entry.key} / $text',
          );
        }
      }
    });

    testWidgets('notes that the PDF is not tagged', (tester) async {
      await pump(tester);

      expect(find.textContaining('not tagged'), findsOneWidget);
    });
  });
}
