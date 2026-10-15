import 'dart:math' show Point;

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/features/browse_sheets/domain/get_sheet.dart';
import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_catalogue_view.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_detail_view.dart';
import 'package:billard_cfa/pages/sheet_catalogue/presentation/sheet_catalogue_page.dart';
import 'package:billard_cfa/pages/sheet_detail/presentation/sheet_detail_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/french_content_notice.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/preview_world.dart';

// Catalogue de séances (ADR 0004, lot L4) : vues, pages et petits composants,
// sur les 28 vraies séances de l'application.

const _features = '[Features]';
const _pages = '[Pages]';

/// Séances proposées au choix : une première séance, une partie 2 et une
/// séance à jeu adapté `[Prop]`.
const _sheetIds = [
  'demi-bille-1',
  'demi-bille-2',
  'posture-1',
  'bille-fantome-1',
  'retro-4',
];

Widget _scroll(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: child,
);

SheetId _chosenSheet(BuildContext context) => SheetId(
  context.knobs.object.dropdown<String>(
    label: 'séance',
    options: _sheetIds,
    initialOption: _sheetIds.first,
  ),
);

@widgetbook.UseCase(
  name: 'Provenance',
  type: ProvenanceBadge,
  path: '[Design system]/Composants',
)
Widget buildProvenanceBadgeUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final provenance in Provenance.values)
        ProvenanceBadge(provenance: provenance),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Contenu en français (interface anglaise)',
  type: FrenchContentNotice,
  path: '[Design system]/Composants',
)
Widget buildFrenchContentNoticeUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Localizations.override(
    context: context,
    locale: const Locale('en'),
    child: const FrenchContentNotice(),
  ),
);

@widgetbook.UseCase(
  name: 'Illustration de séance',
  type: SheetIllustrationView,
  path: '[Design system]/Illustrations',
)
Widget buildSheetIllustrationViewUseCase(BuildContext context) => _scroll(
  SheetIllustrationView(
    illustration: const Illustration.ghostAim(
      id: 'visee',
      caption: 'La bille fantôme montre où la blanche touche la cible.',
      alt: 'Blanche, bille de couleur, poche et bille fantôme.',
      cue: Point(1.84, 2.26),
      object: Point(5, 2),
      pocket: TablePocket.tr,
      fraction: ContactFraction.half,
    ),
    diagrams: const {},
    proposal: context.knobs.boolean(
      label: 'élément [Prop] (badge Proposition)',
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Catalogue',
  type: SheetCatalogueView,
  path: _features,
)
Widget buildSheetCatalogueViewUseCase(BuildContext context) {
  final filter = context.knobs.object.dropdown<SheetReviewFilter>(
    label: 'filtre « à valider »',
    options: SheetReviewFilter.values,
    labelBuilder: (value) => value.name,
  );
  return WorldScope(
    builder: (context, world) => LoadedScope<SheetCatalogue>(
      load: (_) => getIt<ListSheets>()(),
      builder: (context, world, catalogue) => _scroll(
        SheetCatalogueView(
          catalogue: catalogue.filtered(filter),
          filter: filter,
          onFilter: (_) {},
          onOpenSheet: (_) {},
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Séance', type: SheetDetailView, path: _features)
Widget buildSheetDetailViewUseCase(BuildContext context) {
  final id = _chosenSheet(context);
  final audience = context.knobs.object.dropdown<Audience>(
    label: 'public',
    options: Audience.values,
    initialOption: Audience.children,
    labelBuilder: (a) => a.name,
  );
  return WorldScope(
    builder: (context, world) => LoadedScope<SheetDetail>(
      key: ValueKey(id),
      load: (_) => getIt<GetSheet>()(id),
      builder: (context, world, detail) => _scroll(
        SheetDetailView(
          detail: detail,
          audience: audience,
          onAudienceChanged: (_) {},
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Catalogue de séances',
  type: SheetCataloguePage,
  path: _pages,
)
Widget buildSheetCataloguePageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider(
    create: (_) =>
        getIt<SheetCatalogueBloc>()..add(const SheetCatalogueEvent.started()),
    child: SheetCataloguePage(onOpenSheet: (_) {}, onOpenSuggestion: () {}),
  ),
);

@widgetbook.UseCase(
  name: 'Séance du catalogue',
  type: SheetDetailPage,
  path: _pages,
)
Widget buildSheetDetailPageUseCase(BuildContext context) {
  final id = _chosenSheet(context);
  return WorldScope(
    builder: (context, world) => BlocProvider(
      key: ValueKey(id),
      create: (_) =>
          getIt<SheetDetailBloc>()..add(SheetDetailEvent.started(sheetId: id)),
      child: SheetDetailPage(
        onBack: () {},
        onHome: () {},
        onPlan: (_) {},
        onLaunch: (_) {},
      ),
    ),
  );
}
