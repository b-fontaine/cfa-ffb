import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_scene_painter.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Clé de l'aperçu d'impression : repère des scénarios de comportement.
const printPreviewKey = ValueKey<String>('print-preview');

/// Aperçu d'une page du document à imprimer : la même scène que celle du PDF,
/// sur une feuille blanche à l'échelle de la largeur disponible. Les lecteurs
/// d'écran en entendent « Aperçu du PDF, page n sur N » ; le contenu est déjà
/// lisible sur l'écran de la séance.
class PrintPreviewView extends StatelessWidget {
  const PrintPreviewView({
    required this.document,
    required this.page,
    super.key = printPreviewKey,
  });

  final PrintDocument document;

  /// Page montrée, à partir de 0 (ramenée dans le document).
  final int page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = page.clamp(0, document.pages.length - 1);
    final current = document.pages[index];
    return Semantics(
      label: l10n.exportPreviewSemantics(index + 1, document.pages.length),
      image: true,
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              elevation: 2,
              color: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadii.small)),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: current.width / current.height,
                child: CustomPaint(
                  painter: PrintScenePainter(
                    current,
                    fontFamily: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.fontFamily,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
