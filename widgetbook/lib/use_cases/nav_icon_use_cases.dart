import 'package:billard_cfa/shared/ui/nav_icon.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

@widgetbook.UseCase(name: 'Interactif', type: NavIcon, path: _path)
Widget buildNavIconUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: IconTheme(
    data: IconThemeData(
      size: context.knobs.double.slider(
        label: 'taille',
        initialValue: 24,
        min: 16,
        max: 96,
      ),
      color: Theme.of(context).colorScheme.onSurface,
    ),
    child: NavIcon(
      context.knobs.object.dropdown(
        label: 'glyphe',
        options: NavGlyph.values,
        labelBuilder: (glyph) => glyph.name,
      ),
      selected: context.knobs.boolean(label: 'sélectionné'),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Les cinq glyphes (contour et plein)',
  type: NavIcon,
  path: _path,
)
Widget buildNavGlyphsUseCase(BuildContext context) {
  final color = Theme.of(context).colorScheme.onSurface;
  return Padding(
    padding: const EdgeInsets.all(16),
    child: IconTheme(
      data: IconThemeData(size: 48, color: color),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          for (final glyph in NavGlyph.values)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [NavIcon(glyph), NavIcon(glyph, selected: true)],
                ),
                Text(glyph.name),
              ],
            ),
        ],
      ),
    ),
  );
}
