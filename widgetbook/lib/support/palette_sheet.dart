import 'package:flutter/material.dart';

/// Planche des jetons de couleur du `ColorScheme` courant.
class PaletteSheet extends StatelessWidget {
  const PaletteSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final swatches = <(String, Color, Color)>[
      ('primary', s.primary, s.onPrimary),
      ('primaryContainer', s.primaryContainer, s.onPrimaryContainer),
      ('secondary', s.secondary, s.onSecondary),
      ('secondaryContainer', s.secondaryContainer, s.onSecondaryContainer),
      ('tertiary', s.tertiary, s.onTertiary),
      ('tertiaryContainer', s.tertiaryContainer, s.onTertiaryContainer),
      ('error', s.error, s.onError),
      ('errorContainer', s.errorContainer, s.onErrorContainer),
      ('surface', s.surface, s.onSurface),
      ('surfaceContainer', s.surfaceContainer, s.onSurface),
      ('inverseSurface', s.inverseSurface, s.onInverseSurface),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (name, background, foreground) in swatches)
            Container(
              width: 168,
              height: 72,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: s.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(name, style: TextStyle(color: foreground)),
            ),
        ],
      ),
    );
  }
}
