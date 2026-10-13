import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/session_sheet/data/session_sheet_yaml_parser.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/illustration_gallery.dart';
import 'package:widgetbook_workspace/support/preview_world.dart';

const _pilotAsset = 'packages/billard_cfa/assets/fiches/09-demi-bille-1.yaml';

Future<(List<Illustration>, DiagramLibrary)> _load() async {
  final text = await rootBundle.loadString(_pilotAsset);
  final library = await getIt<DiagramRepository>().load();
  return (parseSessionSheet(text).illustrations, library);
}

/// Les 10 types d'illustration du FORMAT des séances : ceux du pilote
/// `demi-bille-1` lus par le vrai parseur, les autres en exemples.
@widgetbook.UseCase(
  name: 'Galerie des illustrations',
  type: Illustration,
  path: '[Design system]/Illustrations',
)
Widget buildIllustrationGalleryUseCase(BuildContext context) {
  final presenting = context.knobs.boolean(label: 'affichage élèves (grand)');
  return WorldScope(
    builder: (context, world) => FutureBuilder(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final (pilot, library) = data;
        final entries = galleryEntries(pilot);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: presenting ? 760 : 380,
                  child: GalleryCard(
                    entry: entry,
                    library: library,
                    presenting: presenting,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
