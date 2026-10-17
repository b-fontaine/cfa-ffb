import 'package:billard_cfa/features/export_sheet/domain/exported_document.dart';
import 'package:billard_cfa/features/export_sheet/domain/layout_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

export 'package:billard_cfa/features/export_sheet/domain/exported_document.dart';

/// Cas d'usage : la feuille de l'animateur d'une séance du catalogue en PDF.
///
/// Mise en page avec la mesure de la fonte du rendu, puis rendu. L'entrée est
/// sans donnée d'élève : ce cas d'usage ne lit aucun dépôt. Un texte que la
/// fonte ne sait pas dessiner donne `InvariantViolation(unprintableContent)`,
/// rien n'est rendu.
@injectable
class ExportAnimatorSheet {
  ExportAnimatorSheet(this._renderer);

  final PrintRenderer _renderer;

  Future<Result<ExportedDocument>> call(SheetPrintInput input) =>
      runGuarded(() async {
        final session = await _renderer.open();
        final document = layoutAnimatorSheet(input, session.measure);
        return ExportedDocument(
          document: document,
          bytes: await session.render(document),
          fileName: input.fileName,
        );
      });
}
