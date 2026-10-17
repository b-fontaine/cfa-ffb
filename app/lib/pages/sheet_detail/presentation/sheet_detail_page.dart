import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_detail_bloc.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_detail_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Largeur du contenu : assez large pour les cartes d'exercice à deux colonnes.
const double _maxWidth = 1100;

/// Une séance du catalogue en mode « Préparer » (bloc fourni par l'appelant).
/// [onBack] revient à l'origine de la page (catalogue, planificateur ou
/// Aujourd'hui) et [backLabel] la nomme ; [onHome] est proposé quand la séance
/// n'existe pas ; [onPlan] ouvre le planificateur sur cette séance ;
/// [onLaunch] lance la séance guidée pour le public affiché, [onExport] ouvre
/// l'export PDF. Le menu ⋮
/// « Signaler une proposition » copie l'identifiant de la séance (en attendant
/// le workflow de validation).
class SheetDetailPage extends StatelessWidget {
  const SheetDetailPage({
    required this.onBack,
    required this.onHome,
    required this.onPlan,
    required this.onLaunch,
    required this.onExport,
    required this.backLabel,
    super.key,
  });

  final VoidCallback onBack;

  /// Le nom de l'origine, sur le bouton de retour.
  final String backLabel;
  final VoidCallback onHome;

  /// Planifie cette séance du catalogue, pour le public affiché.
  final ValueChanged<Audience> onPlan;

  /// Lance la séance guidée, pour le public affiché.
  final ValueChanged<Audience> onLaunch;

  /// Ouvre l'export PDF (feuille de l'animateur, fiches résultats), pour le
  /// public affiché.
  final ValueChanged<Audience> onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SheetDetailBloc, SheetDetailState>(
      builder: (context, state) {
        final detail = state.detail;
        return switch (state.status) {
          SheetDetailStatus.loading => const Scaffold(body: LoadingView()),
          SheetDetailStatus.notFound => MissingPageView(onHome: onHome),
          SheetDetailStatus.failure => Scaffold(
            body: ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: () => context.read<SheetDetailBloc>().add(
                const SheetDetailEvent.retried(),
              ),
              onBack: onBack,
            ),
          ),
          SheetDetailStatus.ready => ScrollPage(
            title: l10n.sheetFullTitle(
              detail!.sheet.title,
              detail.sheet.part,
              detail.partCount,
            ),
            onBack: onBack,
            backLabel: backLabel,
            maxWidth: _maxWidth,
            actions: [
              _SheetMenu(sheet: detail.sheet, partCount: detail.partCount),
            ],
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => onLaunch(state.audience),
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: Text(l10n.guideLaunch),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onPlan(state.audience),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(l10n.sheetPlan),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onExport(state.audience),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l10n.exportMenu),
                  ),
                ],
              ),
              SheetDetailView(
                detail: detail,
                audience: state.audience,
                onAudienceChanged: (audience) => context
                    .read<SheetDetailBloc>()
                    .add(SheetDetailEvent.audienceChanged(audience: audience)),
              ),
            ],
          ),
        };
      },
    );
  }
}

enum _SheetAction { report }

/// Menu ⋮ de la séance : « Signaler une proposition » copie l'identifiant de
/// la séance et le dit ; si la copie échoue, l'identifiant est affiché en
/// clair (jamais d'échec muet).
class _SheetMenu extends StatelessWidget {
  const _SheetMenu({required this.sheet, required this.partCount});

  final SessionSheet sheet;
  final int partCount;

  Future<void> _report(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = sheet.id.value;
    final text = l10n.sheetReportText(
      id,
      l10n.sheetFullTitle(sheet.title, sheet.part, partCount),
    );
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      message = l10n.sheetReportCopied(id);
    } on Object {
      message = l10n.sheetReportFailed(id);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_SheetAction>(
      key: const ValueKey('sheet-menu'),
      tooltip: l10n.sheetMenuTooltip,
      onSelected: (_) => _report(context),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _SheetAction.report,
          child: Text(l10n.sheetReport),
        ),
      ],
    );
  }
}
