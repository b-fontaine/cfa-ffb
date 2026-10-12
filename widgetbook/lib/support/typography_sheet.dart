import 'package:flutter/material.dart';

/// Échelle typographique du thème courant.
class TypographySheet extends StatelessWidget {
  const TypographySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final styles = <(String, TextStyle?)>[
      ('displaySmall 36/44', t.displaySmall),
      ('headlineMedium 28/36', t.headlineMedium),
      ('titleLarge 22/28', t.titleLarge),
      ('titleMedium 16/24', t.titleMedium),
      ('bodyLarge 16/24', t.bodyLarge),
      ('bodyMedium 14/20', t.bodyMedium),
      ('labelLarge 14/20', t.labelLarge),
      ('labelSmall 12/16', t.labelSmall),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, style) in styles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(name, style: style),
            ),
        ],
      ),
    );
  }
}
