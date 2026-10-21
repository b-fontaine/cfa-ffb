import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_actions.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_view.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

const _g1 = GroupId('g1');
const _g2 = GroupId('g2');
const _outline = ImportOutline(
  groups: [
    OutlineGroup(
      id: _g1,
      name: 'Mardi',
      audience: Audience.children,
      seasonLabel: '2026-2027',
      students: 4,
    ),
    OutlineGroup(
      id: _g2,
      name: 'Jeudi',
      audience: Audience.children,
      seasonLabel: null,
      students: 1,
    ),
  ],
);
const _targets = [
  ImportTarget(
    id: GroupId('c1'),
    name: 'Club enfants',
    audience: Audience.children,
  ),
  ImportTarget(
    id: GroupId('c2'),
    name: 'Club adultes',
    audience: Audience.adults,
  ),
];

ClubImportPlan _plan(
  ImportStatus status, {
  ImportReport? report,
  ImportOutline outline = _outline,
  List<ImportLot> lots = const [],
  int startLot = 0,
}) => ClubImportPlan(
  status: status,
  report:
      report ??
      const ImportReport(
        counts: {
          ImportCategory.groups: ImportCount(inFile: 2, writes: 2),
          ImportCategory.students: ImportCount(inFile: 5, writes: 5),
        },
      ),
  outline: outline,
  lots: lots,
  startLot: startLot,
);

Future<void> _pump(
  WidgetTester tester,
  ClubImportState state, {
  ClubImportActions actions = ClubImportActions.none,
  Locale locale = const Locale('en'),
}) => pumpUi(
  tester,
  SingleChildScrollView(
    child: ClubImportView(state: state, actions: actions),
  ),
  locale: locale,
);

void main() {
  testWidgets(
    'file step: guide, role, and a pick button that needs the network',
    (tester) async {
      await _pump(tester, const ClubImportState(role: Role.director));
      expect(find.text('Choose the file'), findsOneWidget);
      expect(find.text('Move my local data'), findsOneWidget);
      expect(
        find.textContaining(
          'The same account does not import the same file twice; '
          'another account could, but would overwrite nothing.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('only once'), findsNothing);
      expect(find.textContaining('children’s data'), findsOneWidget);
      expect(find.text('You are importing as: Director.'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Choose a backup file');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await _pump(tester, const ClubImportState(online: false));
      expect(
        find.text('Offline: the import needs a connection.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await _pump(tester, const ClubImportState(busy: true));
      expect(find.text('Reading and checking the file…'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    },
  );

  testWidgets('file step: a failure to read the club is localised', (
    tester,
  ) async {
    await _pump(
      tester,
      const ClubImportState(
        failure: ServiceFailure(ServiceFailureCode.unavailable),
      ),
    );
    expect(find.textContaining('The service is not responding'), findsWidgets);
  });

  testWidgets(
    'report step blocked: localised problems, no child data, no way on',
    (tester) async {
      final plan = _plan(
        ImportStatus.blocked,
        report: const ImportReport(
          counts: {},
          problems: [
            ImportProblem(ImportProblemCode.unreadable, null),
            ImportProblem(
              ImportProblemCode.duplicateId,
              ImportCategory.students,
              count: 3,
              sample: ['s-1'],
            ),
          ],
        ),
      );
      await _pump(
        tester,
        ClubImportState(step: ClubImportStep.report, plan: plan),
      );
      expect(find.text('Import not possible'), findsOneWidget);
      expect(
        find.textContaining('The file is not a readable backup.'),
        findsWidgets,
      );
      expect(find.textContaining('Students: '), findsWidgets);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Choose another file'), findsOneWidget);
      expect(find.textContaining('s-1'), findsNothing);
    },
  );

  testWidgets('report step: counters, warnings, already imported, started', (
    tester,
  ) async {
    final plan = _plan(
      ImportStatus.needsDecisions,
      report: const ImportReport(
        counts: {ImportCategory.groups: ImportCount(inFile: 2, writes: 2)},
        warnings: {ImportWarning.staleFile},
        fileAgeDays: 40,
        undecidedGroups: [_g1],
      ),
    );
    await _pump(
      tester,
      ClubImportState(step: ClubImportStep.report, plan: plan),
    );
    expect(find.textContaining('Groups: 2 in the file'), findsOneWidget);
    expect(find.textContaining('40 days'), findsOneWidget);
    expect(
      find.textContaining('1 group of the file to create or match'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.report,
        plan: _plan(ImportStatus.alreadyImported),
      ),
    );
    expect(
      find.textContaining('already fully imported by this account'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsNothing);

    const marker = ImportMarker(
      fileId: 'f',
      planId: 'p',
      lots: 5,
      done: 2,
      writes: 100,
      restored: 0,
      role: Role.director,
    );
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.report,
        plan: _plan(
          ImportStatus.needsDecisions,
          outline: const ImportOutline(marker: marker),
        ),
      ),
    );
    expect(
      find.textContaining(
        'An import of this file by this account has started: 2 of 5',
      ),
      findsOneWidget,
    );
  });

  testWidgets('groups step: create or match, teacher cannot create', (
    tester,
  ) async {
    final plan = _plan(
      ImportStatus.needsDecisions,
      report: const ImportReport(counts: {}, undecidedGroups: [_g1, _g2]),
    );
    final chosen = <(GroupId, GroupChoice?)>[];
    final actions = ClubImportActions(
      onPick: ClubImportActions.none.onPick,
      onChooseGroup: (g, c) async => chosen.add((g, c)),
      onConfirmMerge: ClubImportActions.none.onConfirmMerge,
      onChooseSession: ClubImportActions.none.onChooseSession,
      onChooseStudent: ClubImportActions.none.onChooseStudent,
      onConfirmRestore: ClubImportActions.none.onConfirmRestore,
      onConfirmUnverified: ClubImportActions.none.onConfirmUnverified,
      onNext: () {},
      onBack: () {},
      onRestart: () {},
      onStart: ClubImportActions.none.onStart,
      onCancel: () {},
      onResume: ClubImportActions.none.onResume,
      onFinish: () {},
    );
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.groups,
        role: Role.director,
        canCreateGroups: true,
        plan: plan,
        targets: _targets,
      ),
      actions: actions,
    );
    expect(find.text('Matching the groups'), findsOneWidget);
    expect(find.text('Children · 2026-2027 · 4 students'), findsOneWidget);
    expect(find.text('Children · 1 student'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('import-group-g1')));
    await tester.pumpAndSettle();
    // Seul le groupe du club de même public est proposé.
    expect(find.text('Match to: Club enfants'), findsWidgets);
    expect(find.text('Match to: Club adultes'), findsNothing);
    await tester.tap(find.text('Create in the club').last);
    await tester.pumpAndSettle();
    expect(chosen.single.$1, _g1);
    expect(chosen.single.$2, isA<CreateGroup>());

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.groups,
        role: Role.teacher,
        plan: plan,
        targets: [],
      ),
    );
    expect(find.textContaining('you cannot create a group'), findsOneWidget);
    expect(find.textContaining('No club group can receive'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('import-group-g1')));
    await tester.pumpAndSettle();
    expect(find.text('Create in the club'), findsNothing);
  });

  testWidgets('groups step: two groups on one target need an explicit merge', (
    tester,
  ) async {
    final plan = _plan(
      ImportStatus.blocked,
      report: const ImportReport(
        counts: {},
        problems: [ImportProblem(ImportProblemCode.mergeNotConfirmed, null)],
      ),
    );
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.groups,
        role: Role.director,
        canCreateGroups: true,
        plan: plan,
        targets: _targets,
        decisions: const ImportDecisions(
          groups: {
            _g1: UseExistingGroup(GroupId('c1')),
            _g2: UseExistingGroup(GroupId('c1')),
          },
        ),
      ),
    );
    expect(find.byKey(const ValueKey('import-merge-c1')), findsOneWidget);
    expect(find.textContaining('merged into “Club enfants”'), findsOneWidget);
    expect(find.textContaining('Two groups of the file'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('loose step: one explicit choice per item, never guessed', (
    tester,
  ) async {
    final plan = _plan(
      ImportStatus.needsDecisions,
      report: const ImportReport(
        counts: {},
        undecidedGroups: [_g2],
        undecidedSessions: ['p1'],
        undecidedStudents: [StudentId('s1')],
      ),
      outline: ImportOutline(
        groups: _outline.groups,
        looseSessions: [
          OutlineSession(id: 'p1', title: 'Libre', date: DateTime(2026, 11, 5)),
        ],
        looseStudents: const [
          OutlineStudent(id: StudentId('s1'), firstName: 'Zoé'),
        ],
      ),
    );
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.loose,
        role: Role.director,
        canCreateGroups: true,
        plan: plan,
        decisions: const ImportDecisions(groups: {_g1: CreateGroup()}),
      ),
    );
    expect(find.text('Sessions and students without a group'), findsOneWidget);
    expect(find.text('Planned sessions without a group'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-session-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-student-s1')), findsOneWidget);
    expect(find.text('To choose'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('import-student-s1')));
    await tester.pumpAndSettle();
    expect(find.text('Attach to: Mardi'), findsWidgets);
    expect(find.text('Attach to: Jeudi'), findsNothing);
    expect(find.text('Skip (do not import)'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('confirm step: exact numbers, consequences, checkboxes', (
    tester,
  ) async {
    const report = ImportReport(
      counts: {},
      restoredStudents: 3,
      unverifiableStudents: 2,
    );
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.confirmations,
        role: Role.teacher,
        plan: _plan(ImportStatus.needsConfirmation, report: report),
      ),
    );
    expect(find.text('Confirmations'), findsOneWidget);
    expect(find.text('I confirm restoring 3 students'), findsOneWidget);
    expect(find.textContaining('check before confirming'), findsOneWidget);
    expect(
      find.text('I confirm creating 2 records that cannot be checked'),
      findsOneWidget,
    );
    expect(find.textContaining('refuse the whole batch'), findsOneWidget);
    final box = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('import-confirm-restore')),
    );
    expect(box.value, isFalse);

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.confirmations,
        plan: _plan(ImportStatus.ready, report: report),
        decisions: const ImportDecisions(
          restoreConfirmed: 3,
          unverifiedConfirmed: 2,
        ),
      ),
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('import-confirm-restore')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('recap step: writes, batches, days, role, resume', (
    tester,
  ) async {
    final lots = [for (var i = 0; i < 4; i++) ImportLot(i, const [])];
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.recap,
        role: Role.admin,
        plan: _plan(ImportStatus.ready, lots: lots),
      ),
    );
    expect(find.text('Summary before writing'), findsOneWidget);
    expect(find.text('4 writes to do'), findsOneWidget);
    expect(find.textContaining('in 4 batches'), findsOneWidget);
    expect(find.text('Duration: 1 day.'), findsOneWidget);
    expect(find.text('Effective role: Administrator'), findsOneWidget);
    expect(find.text('Import now'), findsOneWidget);

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.recap,
        role: Role.director,
        canCreateGroups: true,
        plan: _plan(ImportStatus.resumable, lots: lots, startLot: 2),
      ),
    );
    expect(find.text('Resuming at batch 3 of 4.'), findsOneWidget);
    expect(find.text('Resume the import'), findsOneWidget);

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.recap,
        online: false,
        plan: _plan(ImportStatus.ready, lots: lots),
      ),
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import now'))
          .onPressed,
      isNull,
    );
  });

  group('run step', () {
    ClubImportState state(ClubImportRun run, {Failure? failure}) =>
        ClubImportState(
          step: ClubImportStep.running,
          run: run,
          doneLots: 2,
          totalLots: 5,
          runFailure: failure,
          plan: _plan(ImportStatus.ready),
        );

    testWidgets('progress is a live region and can be stopped', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, state(ClubImportRun.running));
      expect(find.text('2 of 5 batches written'), findsOneWidget);
      expect(find.text('Stop after this batch'), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel('2 of 5 batches written'),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('cancelling, cancelled, paused, interrupted are not errors', (
      tester,
    ) async {
      await _pump(tester, state(ClubImportRun.cancelling));
      expect(
        find.textContaining('the current batch is finishing'),
        findsOneWidget,
      );

      await _pump(tester, state(ClubImportRun.cancelled));
      expect(
        find.textContaining('Import stopped after 2 of 5'),
        findsOneWidget,
      );
      expect(find.text('Resume'), findsOneWidget);

      await _pump(tester, state(ClubImportRun.paused));
      expect(find.text('Paused: daily limit reached'), findsNothing);
      expect(
        find.textContaining('Paused: daily limit reached'),
        findsOneWidget,
      );
      expect(find.textContaining('Resume tomorrow'), findsOneWidget);
      expect(find.text('Action needed'), findsNothing);

      await _pump(tester, state(ClubImportRun.interrupted));
      expect(
        find.textContaining('Import interrupted: no connection'),
        findsOneWidget,
      );
      expect(find.text('Action needed'), findsNothing);
    });

    testWidgets('a rule refusal and a plan change are said soberly', (
      tester,
    ) async {
      await _pump(
        tester,
        state(
          ClubImportRun.failed,
          failure: const ServiceFailure(ServiceFailureCode.denied),
        ),
      );
      expect(
        find.textContaining('The server refused to write a batch'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      await _pump(tester, state(ClubImportRun.planChanged));
      expect(
        find.textContaining('with exactly the same choices'),
        findsOneWidget,
      );
    });
  });

  testWidgets('done step: summary without personal data', (tester) async {
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.finished,
        plan: _plan(ImportStatus.ready, lots: const [ImportLot(0, [])]),
      ),
    );
    expect(find.text('Import finished'), findsOneWidget);
    expect(
      find.textContaining('Keep the file in a safe place'),
      findsOneWidget,
    );
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('French texts and tap targets of every actionable step', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const ClubImportState(role: Role.director),
      locale: const Locale('fr'),
    );
    expect(find.text('Choisir le fichier'), findsOneWidget);
    expect(find.text('Migrer mes données locales'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.groups,
        role: Role.director,
        canCreateGroups: true,
        targets: _targets,
        plan: _plan(
          ImportStatus.needsDecisions,
          report: const ImportReport(counts: {}, undecidedGroups: [_g1]),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.confirmations,
        plan: _plan(
          ImportStatus.needsConfirmation,
          report: const ImportReport(counts: {}, restoredStudents: 1),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the step title is a header and a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const ClubImportState());
    final node = tester.getSemantics(find.text('Choose the file'));
    expect(node.flagsCollection.isHeader, isTrue);
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('French guide and end note: the same account does not import '
      'twice, another could without overwriting anything', (tester) async {
    await _pump(
      tester,
      const ClubImportState(role: Role.director),
      locale: const Locale('fr'),
    );
    expect(
      find.textContaining(
        'Le même compte ne ré-importe pas deux fois le même fichier ; '
        'un autre compte le pourrait, mais n’écraserait rien.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('qu’une seule fois'), findsNothing);

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.finished,
        plan: _plan(ImportStatus.ready),
      ),
      locale: const Locale('fr'),
    );
    expect(
      find.textContaining(
        'Ce compte ne peut pas le ré-importer ; un autre '
        'compte le pourrait, mais n’écraserait rien.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('seconde fois'), findsNothing);

    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.finished,
        plan: _plan(ImportStatus.ready),
      ),
    );
    expect(
      find.textContaining(
        'This account cannot import it again; another '
        'account could, but would overwrite nothing.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('second time'), findsNothing);
  });

  testWidgets('a choice menu announces its question once', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      ClubImportState(
        step: ClubImportStep.groups,
        role: Role.director,
        canCreateGroups: true,
        targets: _targets,
        plan: _plan(
          ImportStatus.needsDecisions,
          report: const ImportReport(counts: {}, undecidedGroups: [_g1]),
        ),
      ),
    );
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('What to do with the group')),
    );
    expect(
      'What to do with the group “Mardi”?'.allMatches(node.label).length,
      1,
      reason: node.label,
    );
    handle.dispose();
  });

  group('live regions', () {
    ClubImportState running(ClubImportRun? run, {bool online = true}) =>
        ClubImportState(
          step: ClubImportStep.running,
          run: run,
          online: online,
          doneLots: 2,
          totalLots: 5,
          runFailure: run == ClubImportRun.failed
              ? const ServiceFailure(ServiceFailureCode.other)
              : null,
          plan: _plan(ImportStatus.ready),
        );

    final states = <String, ClubImportState>{
      'file': const ClubImportState(),
      'file, reading': const ClubImportState(busy: true),
      'file, offline': const ClubImportState(online: false),
      'file, failure': const ClubImportState(
        failure: ServiceFailure(ServiceFailureCode.unavailable),
      ),
      'report': ClubImportState(
        step: ClubImportStep.report,
        plan: _plan(ImportStatus.ready),
      ),
      'recap': ClubImportState(
        step: ClubImportStep.recap,
        plan: _plan(ImportStatus.ready),
      ),
      'finished': ClubImportState(
        step: ClubImportStep.finished,
        plan: _plan(ImportStatus.ready),
      ),
      'running': running(ClubImportRun.running),
      'running, offline': running(ClubImportRun.running, online: false),
      'cancelling': running(ClubImportRun.cancelling),
      'cancelled': running(ClubImportRun.cancelled),
      'paused': running(ClubImportRun.paused),
      'interrupted': running(ClubImportRun.interrupted),
      'interrupted, offline': running(ClubImportRun.interrupted, online: false),
      'failed': running(ClubImportRun.failed),
      'plan changed': running(ClubImportRun.planChanged),
    };

    List<SemanticsNode> live(SemanticsNode root) {
      final found = <SemanticsNode>[];
      void walk(SemanticsNode n) {
        if (n.flagsCollection.isLiveRegion) found.add(n);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(root);
      return found;
    }

    bool hasButton(SemanticsNode root) {
      var found = false;
      void walk(SemanticsNode n) {
        if (n.flagsCollection.isButton) found = true;
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(root);
      return found;
    }

    for (final entry in states.entries) {
      testWidgets('${entry.key}: one polite live region, no button in it', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, entry.value);
        final root = tester.getSemantics(find.byType(ClubImportView));
        final regions = live(root);
        expect(
          regions,
          hasLength(1),
          reason: '${entry.key} ${regions.map((r) => r.label)}',
        );
        expect(hasButton(regions.single), isFalse, reason: entry.key);
        handle.dispose();
      });
    }
  });

  for (final (locale, already, started) in [
    (
      const Locale('fr'),
      'Ce fichier est déjà entièrement importé par ce compte dans ce club : '
          'il n’y a rien à faire.',
      'Un import de ce fichier par ce compte est commencé : 2 lots sur 5.',
    ),
    (
      const Locale('en'),
      'This file is already fully imported by this account into this club: '
          'there is nothing to do.',
      'An import of this file by this account has started: 2 of 5 batches.',
    ),
  ]) {
    testWidgets('report step names the account (${locale.languageCode})', (
      tester,
    ) async {
      await _pump(
        tester,
        ClubImportState(
          step: ClubImportStep.report,
          plan: _plan(ImportStatus.alreadyImported),
        ),
        locale: locale,
      );
      expect(find.text(already), findsOneWidget);

      const marker = ImportMarker(
        fileId: 'f',
        planId: 'p',
        lots: 5,
        done: 2,
        writes: 100,
        restored: 0,
        role: Role.director,
      );
      await _pump(
        tester,
        ClubImportState(
          step: ClubImportStep.report,
          plan: _plan(
            ImportStatus.needsDecisions,
            outline: const ImportOutline(marker: marker),
          ),
        ),
        locale: locale,
      );
      expect(find.textContaining(started), findsOneWidget);
    });
  }
}
