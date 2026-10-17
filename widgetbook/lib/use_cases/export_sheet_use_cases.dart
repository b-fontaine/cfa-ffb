import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/sheet_export.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/presentation/bloc/export_sheet_cubit.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/export_view.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_preview_view.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/pages/export_sheet/presentation/export_sheet_page.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

// Export PDF (ADR 0021, lot 14) : l'aperçu d'une page, le contenu de l'écran
// d'export et la page, sur les 28 vraies séances de l'application.

const _features = '[Features]';
const _pages = '[Pages]';

const _sheetIds = [
  'demi-bille-1',
  'demi-bille-2',
  'posture-1',
  'bille-fantome-1',
  'retro-4',
];

SheetId _chosenSheet(BuildContext context) => SheetId(
  context.knobs.object.dropdown<String>(
    label: 'séance',
    options: _sheetIds,
    initialOption: _sheetIds.first,
  ),
);

Audience _chosenAudience(BuildContext context) =>
    context.knobs.object.dropdown<Audience>(
      label: 'public',
      options: Audience.values,
      initialOption: Audience.children,
      labelBuilder: (audience) => audience.name,
    );

ExportKind _chosenKind(BuildContext context) =>
    context.knobs.object.dropdown<ExportKind>(
      label: 'document',
      options: ExportKind.values,
      initialOption: ExportKind.animator,
      labelBuilder: (kind) => kind.name,
    );

RunPlanExportSource _source(AppLocalizations l10n, SheetId id) =>
    RunPlanExportSource(
      sheetId: id,
      l10n: l10n,
      printedOn: '12 oct. 2026',
      resolve: (sheet, audience) => getIt<ResolveRunPlan>()(
        sheet,
        audience: audience,
        withRecallExercise: false,
      ),
    );

/// Produit le document de la séance [id] avec les vrais cas d'usage.
Future<ExportedDocument> _document(
  AppLocalizations l10n,
  SheetId id,
  Audience audience,
  ExportKind kind,
) async {
  final source = _source(l10n, id);
  final renderer = getIt<PrintRenderer>();
  final result = switch (kind) {
    ExportKind.animator => switch (await source.animator(audience)) {
      Ok(:final value) => await ExportAnimatorSheet(renderer)(value),
      Err(:final failure) => Err<ExportedDocument>(failure),
    },
    ExportKind.results => switch (await source.results(audience)) {
      Ok(:final value) => await getIt<ExportResultsSheets>()(
        ResultsSheetsRequest(
          title: value.title,
          fileName: value.fileName,
          series: value.series,
          columns: value.columns,
          labels: value.labels,
        ),
      ),
      Err(:final failure) => Err<ExportedDocument>(failure),
    },
  };
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('export impossible : $failure'),
  };
}

/// Charge un document puis le remet à `builder` ; recharge quand la séance, le
/// public ou le document change.
class _DocumentScope extends StatefulWidget {
  const _DocumentScope({
    required this.id,
    required this.audience,
    required this.kind,
    required this.builder,
  });

  final SheetId id;
  final Audience audience;
  final ExportKind kind;
  final Widget Function(BuildContext context, ExportedDocument document)
  builder;

  @override
  State<_DocumentScope> createState() => _DocumentScopeState();
}

class _DocumentScopeState extends State<_DocumentScope> {
  Future<ExportedDocument>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void didUpdateWidget(_DocumentScope old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id ||
        old.audience != widget.audience ||
        old.kind != widget.kind) {
      _future = _load();
    }
  }

  Future<ExportedDocument> _load() {
    final l10n = AppLocalizations.of(context);
    return PreviewWorld.ensure().then(
      (_) => _document(l10n, widget.id, widget.audience, widget.kind),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ExportedDocument>(
    future: _future,
    builder: (context, snapshot) {
      final document = snapshot.data;
      if (document == null) return const LoadingView();
      return widget.builder(context, document);
    },
  );
}

@widgetbook.UseCase(
  name: 'Aperçu d’une page',
  type: PrintPreviewView,
  path: _features,
)
Widget buildPrintPreviewViewUseCase(BuildContext context) => _DocumentScope(
  id: _chosenSheet(context),
  audience: _chosenAudience(context),
  kind: _chosenKind(context),
  builder: (context, exported) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: PrintPreviewView(
      document: exported.document,
      page: context.knobs.int.slider(
        label: 'page (à partir de 0)',
        max: exported.document.pages.length - 1,
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Contenu de l’écran d’export',
  type: ExportView,
  path: _features,
)
Widget buildExportViewUseCase(BuildContext context) {
  final kind = _chosenKind(context);
  final audience = _chosenAudience(context);
  final outcome = context.knobs.object.dropdown<ExportOutcome>(
    label: 'résultat',
    options: ExportOutcome.values,
    initialOption: ExportOutcome.none,
    labelBuilder: (outcome) => outcome.name,
  );
  final preparing = context.knobs.boolean(label: 'préparation en cours');
  final includeNames = context.knobs.boolean(label: 'prénoms du groupe');
  final canPrint = context.knobs.boolean(
    label: 'impression possible',
    initialValue: true,
  );
  return _DocumentScope(
    id: _chosenSheet(context),
    audience: audience,
    kind: kind,
    builder: (context, exported) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ExportView(
        state: ExportSheetState(
          status: ExportStatus.ready,
          kind: kind,
          audience: audience,
          groups: const [GroupChoice(GroupId('enfants'), 'Enfants')],
          groupId: const GroupId('enfants'),
          includeNames: includeNames,
          exported: exported,
          preparing: preparing,
          page: context.knobs.int.slider(
            label: 'page (à partir de 0)',
            max: exported.document.pages.length - 1,
          ),
          outcome: outcome,
          canPrint: canPrint,
        ),
        onKindChanged: (_) {},
        onAudienceChanged: (_) {},
        onGroupChanged: (_) {},
        onNamesChanged: (_) {},
        onPageChanged: (_) {},
        onSave: () {},
        onPrint: () {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Export PDF', type: ExportSheetPage, path: _pages)
Widget buildExportSheetPageUseCase(BuildContext context) {
  final id = _chosenSheet(context);
  final audience = _chosenAudience(context);
  return WorldScope(
    builder: (context, world) => BlocProvider(
      key: ValueKey((id, audience)),
      create: (_) {
        final cubit = getIt<ExportSheetCubit>();
        unawaited(
          cubit.started(
            source: _source(AppLocalizations.of(context), id),
            audience: audience,
          ),
        );
        return cubit;
      },
      child: ExportSheetPage(onBack: () {}, onHome: () {}),
    ),
  );
}
