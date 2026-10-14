import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the selected chip and segment use the cloth blue container
///
/// Affiche une puce de filtre, une puce de choix et un segment sélectionnés
/// sous le thème réel de l'application, et vérifie que leur fond rendu est
/// exactement le `secondaryContainer` du thème (bleu-tapis), jamais le rose
/// ou le rouge d'état.
Future<void> theSelectedChipAndSegmentUseTheClothBlueContainer(
  WidgetTester tester,
) async {
  final context = tester.element(find.byType(Scaffold).first);
  final theme = Theme.of(context);
  final container = theme.colorScheme.secondaryContainer;
  final isDark = theme.brightness == Brightness.dark;
  // Valeurs littérales attendues par thème (famille bleu-tapis).
  expect(container, isDark ? const Color(0xFF1F5873) : const Color(0xFFCFE6F3));

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RepaintBoundary(
          key: _boundaryKey,
          child: Column(
            children: [
              FilterChip(
                label: const Text('filter'),
                selected: true,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('choice'),
                selected: true,
                onSelected: (_) {},
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('one')),
                  ButtonSegment(value: 2, label: Text('two')),
                ],
                selected: const {1},
                onSelectionChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Les puces peignent leur fond dans le rendu (pas dans un `Material`) :
  // on échantillonne donc un pixel de la zone remplie, juste dans le coin
  // gauche de chaque contrôle, à mi-hauteur.
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = (await tester.runAsync(boundary.toImage))!;
  final bytes = (await tester.runAsync(image.toByteData))!;
  final origin = boundary.localToGlobal(Offset.zero);

  Color pixelAt(Finder control) {
    final rect = tester.getRect(control);
    final x = (rect.left - origin.dx + 6).round();
    final y = (rect.center.dy - origin.dy).round();
    final offset = (y * image.width + x) * 4;
    return Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }

  expect(pixelAt(find.byType(FilterChip)), container, reason: 'FilterChip');
  expect(pixelAt(find.byType(ChoiceChip)), container, reason: 'ChoiceChip');
  final selectedSegment = find.ancestor(
    of: find.text('one'),
    matching: find.byType(TextButton),
  );
  final otherSegment = find.ancestor(
    of: find.text('two'),
    matching: find.byType(TextButton),
  );
  expect(pixelAt(selectedSegment), container, reason: 'segment sélectionné');
  expect(
    pixelAt(otherSegment),
    isNot(container),
    reason: 'segment non sélectionné',
  );
}

const ValueKey<String> _boundaryKey = ValueKey('selected-states-boundary');
