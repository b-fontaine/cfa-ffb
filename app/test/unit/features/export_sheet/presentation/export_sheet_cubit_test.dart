import 'dart:async';
import 'dart:convert';

import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/list_export_groups.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/presentation/bloc/export_sheet_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_export_source.dart';
import '../../../../support/fake_pdf_files.dart';
import '../../../../support/fake_print_renderer.dart';
import '../../../../support/fixed_clock.dart';

/// Dépôt de groupes dont la lecture échoue (par un échec métier).
class _BrokenGroupRepository extends InMemoryGroupRepository {
  @override
  Future<List<Group>> all() async => throw const NotFound('group', 'lecture');
}

void main() {
  late FakePrintRenderer renderer;
  late FakePdfFiles files;
  late FakeExportSource source;
  late InMemoryGroupRepository groups;
  late InMemoryStudentRepository students;
  late InMemorySeasonRepository seasons;
  final today = DateTime(2026, 10, 12);

  ExportSheetCubit build() {
    final clock = FixedClock(today);
    return ExportSheetCubit(
      ExportAnimatorSheet(renderer),
      ExportResultsSheets(renderer, groups, students, clock),
      ListExportGroups(groups, seasons, clock),
      files,
    );
  }

  setUp(() async {
    renderer = FakePrintRenderer();
    files = FakePdfFiles();
    source = FakeExportSource();
    groups = InMemoryGroupRepository();
    students = InMemoryStudentRepository();
    seasons = InMemorySeasonRepository();
    await seasons.save(
      Season(
        id: const SeasonId('s'),
        label: '2026-2027',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 6, 30),
      ),
    );
    await students.save(
      Student.enroll(
        id: const StudentId('1'),
        firstName: 'Zoé',
        audience: Audience.children,
        since: DateTime(2026, 9),
      ),
    );
    await groups.save(
      Group(
        id: const GroupId('g1'),
        seasonId: const SeasonId('s'),
        name: 'Mardi',
        audience: Audience.children,
        memberships: [
          Membership(studentId: const StudentId('1'), from: DateTime(2026, 9)),
        ],
      ),
    );
  });

  Future<ExportSheetCubit> started({
    Audience audience = Audience.children,
  }) async {
    final cubit = build();
    await cubit.started(source: source, audience: audience);
    return cubit;
  }

  Iterable<String> sceneTexts(ExportSheetCubit cubit) => cubit
      .state
      .exported!
      .document
      .pages
      .expand((p) => p.items)
      .whereType<PrintText>()
      .map((t) => t.text);

  group('started', () {
    test('prepares the animator sheet for the audience of the page', () async {
      final cubit = await started();

      final state = cubit.state;
      expect(state.status, ExportStatus.ready);
      expect(state.kind, ExportKind.animator);
      expect(state.audience, Audience.children);
      expect(state.exported!.fileName, 'seance-x-children.pdf');
      expect(state.page, 0);
      expect(state.preparing, isFalse);
      expect(state.outcome, ExportOutcome.none);
      expect(sceneTexts(cubit), contains('Texte children'));
      await cubit.close();
    });

    test(
      'offers the groups of the current season and the print capability',
      () async {
        final cubit = await started();

        expect(cubit.state.groups, [const GroupChoice(GroupId('g1'), 'Mardi')]);
        expect(cubit.state.canPrint, isTrue);
        await cubit.close();
      },
    );

    test('hides printing when the platform cannot print', () async {
      files = FakePdfFiles(printSupported: false);
      final cubit = await started();

      expect(cubit.state.canPrint, isFalse);
      await cubit.close();
    });

    test('reports an unknown session as not found', () async {
      source.failure = const NotFound('sheet', 'inconnue-9');
      final cubit = await started();

      expect(cubit.state.status, ExportStatus.notFound);
      expect(cubit.state.exported, isNull);
      await cubit.close();
    });

    test('keeps another failure, an unprintable text for instance', () async {
      source.failure = const InvariantViolation(
        InvariantCode.unprintableContent,
      );
      final cubit = await started();

      expect(cubit.state.status, ExportStatus.failure);
      expect(
        (cubit.state.failure! as InvariantViolation).code,
        InvariantCode.unprintableContent,
      );
      await cubit.close();
    });

    test('keeps the failure of the groups list and still prepares', () async {
      groups = _BrokenGroupRepository();
      final cubit = await started();

      expect(cubit.state.groups, isEmpty);
      expect(cubit.state.groupsFailure, isNotNull);
      expect(cubit.state.status, ExportStatus.ready);
      await cubit.close();
    });

    test('no failure is kept when the groups list is read', () async {
      final cubit = await started();

      expect(cubit.state.groupsFailure, isNull);
      await cubit.close();
    });

    test('shows a preparing state while the document is being built', () async {
      source.gate = Completer<void>();
      final cubit = build();
      final done = cubit.started(source: source, audience: Audience.children);
      await pumpEventQueue();

      expect(cubit.state.status, ExportStatus.loading);

      source.gate!.complete();
      await done;
      expect(cubit.state.status, ExportStatus.ready);
      await cubit.close();
    });
  });

  group('retry and failures', () {
    test('retrying after a failure prepares the document', () async {
      source.failure = const InvariantViolation(
        InvariantCode.unprintableContent,
      );
      final cubit = await started();
      expect(cubit.state.status, ExportStatus.failure);

      source.failure = null;
      await cubit.retried();

      expect(cubit.state.status, ExportStatus.ready);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.exported, isNotNull);
      await cubit.close();
    });

    test(
      'a failure while rendering the results sheets leaves no stale document',
      () async {
        final cubit = await started();
        expect(cubit.state.exported, isNotNull);

        renderer.renderError = const InvariantViolation(
          InvariantCode.unprintableContent,
        );
        await cubit.kindChanged(ExportKind.results);

        expect(cubit.state.status, ExportStatus.failure);
        expect(cubit.state.failure, isNotNull);
        expect(cubit.state.exported, isNull);
        expect(cubit.state.preparing, isFalse);
        await cubit.close();
      },
    );
  });

  group('options', () {
    test(
      'changing the audience rebuilds the document for that audience',
      () async {
        final cubit = await started();

        await cubit.audienceChanged(Audience.adults);

        expect(cubit.state.audience, Audience.adults);
        expect(source.animatorAsked, [Audience.children, Audience.adults]);
        expect(sceneTexts(cubit), contains('Texte adults'));
        expect(cubit.state.exported!.fileName, 'seance-x-adults.pdf');
        await cubit.close();
      },
    );

    test('asking for the audience already shown does nothing', () async {
      final cubit = await started();

      await cubit.audienceChanged(Audience.children);

      expect(source.animatorAsked, [Audience.children]);
      await cubit.close();
    });

    test(
      'switching to the results sheets builds them from the results plan',
      () async {
        final cubit = await started();

        await cubit.kindChanged(ExportKind.results);

        expect(cubit.state.kind, ExportKind.results);
        expect(source.resultsAsked, [Audience.children]);
        expect(cubit.state.exported!.fileName, 'fiches-x-children.pdf');
        expect(sceneTexts(cubit), contains('Fiche Résultats'));
        await cubit.close();
      },
    );

    test(
      'first names are printed only for a chosen group and an explicit request',
      () async {
        final cubit = await started();
        await cubit.kindChanged(ExportKind.results);
        expect(sceneTexts(cubit), isNot(contains('Zoé')));

        await cubit.groupChosen(const GroupId('g1'));
        expect(cubit.state.includeNames, isFalse);
        expect(sceneTexts(cubit), isNot(contains('Zoé')));

        await cubit.namesToggled(value: true);
        expect(cubit.state.includeNames, isTrue);
        expect(sceneTexts(cubit), contains('Zoé'));

        await cubit.namesToggled(value: false);
        expect(sceneTexts(cubit), isNot(contains('Zoé')));
        await cubit.close();
      },
    );

    test('ignores the request for names while no group is chosen', () async {
      final cubit = await started();
      await cubit.kindChanged(ExportKind.results);

      await cubit.namesToggled(value: true);

      expect(cubit.state.includeNames, isFalse);
      await cubit.close();
    });

    test('removing the group also removes the names', () async {
      final cubit = await started();
      await cubit.kindChanged(ExportKind.results);
      await cubit.groupChosen(const GroupId('g1'));
      await cubit.namesToggled(value: true);

      await cubit.groupChosen(null);

      expect(cubit.state.groupId, isNull);
      expect(cubit.state.includeNames, isFalse);
      expect(sceneTexts(cubit), isNot(contains('Zoé')));
      await cubit.close();
    });

    test(
      'the animator sheet never reads the group, whatever is chosen',
      () async {
        final cubit = await started();
        await cubit.kindChanged(ExportKind.results);
        await cubit.groupChosen(const GroupId('g1'));
        await cubit.namesToggled(value: true);

        await cubit.kindChanged(ExportKind.animator);

        expect(sceneTexts(cubit), isNot(contains('Zoé')));
        expect(sceneTexts(cubit), contains('Texte children'));
        await cubit.close();
      },
    );

    test('the last choice wins when answers arrive out of order', () async {
      final cubit = await started();
      final slow = Completer<void>();
      source.gate = slow;
      final first = cubit.audienceChanged(Audience.adults);
      await pumpEventQueue();
      source.gate = null;
      final second = cubit.kindChanged(ExportKind.results);
      await second;
      slow.complete();
      await first;

      expect(cubit.state.kind, ExportKind.results);
      expect(cubit.state.exported!.fileName, 'fiches-x-adults.pdf');
      await cubit.close();
    });

    test('a new choice clears the previous outcome', () async {
      final cubit = await started();
      await cubit.save();
      expect(cubit.state.outcome, ExportOutcome.saved);

      await cubit.audienceChanged(Audience.adults);

      expect(cubit.state.outcome, ExportOutcome.none);
      await cubit.close();
    });
  });

  group('pages', () {
    Future<ExportSheetCubit> twoPages() async {
      final cubit = await started();
      await cubit.kindChanged(ExportKind.results);
      return cubit;
    }

    test('moves from page to page and stays inside the document', () async {
      final cubit = await twoPages();
      expect(cubit.state.pageCount, 2);

      cubit.pageChanged(1);
      expect(cubit.state.page, 1);
      cubit.pageChanged(5);
      expect(cubit.state.page, 1);
      cubit.pageChanged(-3);
      expect(cubit.state.page, 0);
      await cubit.close();
    });

    test('returns to the first page when the document changes', () async {
      final cubit = await twoPages();
      cubit.pageChanged(1);

      await cubit.audienceChanged(Audience.adults);

      expect(cubit.state.page, 0);
      await cubit.close();
    });
  });

  group('save and print', () {
    test('saves the file under its name', () async {
      final cubit = await started();

      await cubit.save();

      expect(cubit.state.outcome, ExportOutcome.saved);
      expect(files.saved.single.fileName, 'seance-x-children.pdf');
      expect(utf8.decode(files.saved.single.bytes), 'PDF 1');
      await cubit.close();
    });

    test('reports a cancelled dialog and writes nothing', () async {
      files.cancelSave = true;
      final cubit = await started();

      await cubit.save();

      expect(cubit.state.outcome, ExportOutcome.cancelled);
      expect(files.saved, isEmpty);
      await cubit.close();
    });

    test('reports a failed write', () async {
      files.saveError = Exception('disque plein');
      final cubit = await started();

      await cubit.save();

      expect(cubit.state.outcome, ExportOutcome.saveFailed);
      await cubit.close();
    });

    test('sends the document to the printer', () async {
      final cubit = await started();

      await cubit.print();

      expect(cubit.state.outcome, ExportOutcome.printed);
      expect(files.printed.single.fileName, 'seance-x-children.pdf');
      expect(files.saved, isEmpty);
      await cubit.close();
    });

    test('reports a failed print instead of an unhandled error', () async {
      files.printError = Exception('imprimante absente');
      final cubit = await started();

      await cubit.print();

      expect(cubit.state.outcome, ExportOutcome.printFailed);
      await cubit.close();
    });

    test('does not print where the platform cannot', () async {
      files = FakePdfFiles(printSupported: false);
      final cubit = await started();

      await cubit.print();

      expect(cubit.state.outcome, ExportOutcome.none);
      expect(files.printed, isEmpty);
      await cubit.close();
    });

    test('does nothing without a document', () async {
      source.failure = const NotFound('sheet', 'x');
      final cubit = await started();

      await cubit.save();
      await cubit.print();

      expect(files.saved, isEmpty);
      expect(files.printed, isEmpty);
      await cubit.close();
    });
  });
}
