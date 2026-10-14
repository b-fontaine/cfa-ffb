import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:billard_cfa/shared/ui/nav_icon.dart';
import 'package:billard_cfa/shared/ui/progress_meter.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/app_typography.dart';
import 'package:billard_cfa/shared/ui/theme/brand_colors.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// Feuille « Rôles de couleur » (ADR 0010) : les états de l'interface dans les
/// thèmes clair et sombre côte à côte, indépendamment du thème choisi dans
/// Widgetbook.
class ColorRolesSheet extends StatelessWidget {
  const ColorRolesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final themes = <(String, ThemeData)>[
      (
        'Clair',
        AppTheme.light(
          fontFamily: AppTypography.packageFontFamily,
          assetPackage: 'billard_cfa',
        ),
      ),
      (
        'Sombre',
        AppTheme.dark(
          fontFamily: AppTypography.packageFontFamily,
          assetPackage: 'billard_cfa',
        ),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (name, data) in themes)
              Theme(
                data: data,
                child: _RolesPanel(name: name),
              ),
          ],
        ),
      ),
    );
  }
}

class _RolesPanel extends StatelessWidget {
  const _RolesPanel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<BrandColors>()!;
    final status = theme.extension<StatusColors>()!;
    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(name, style: theme.textTheme.titleLarge),
              NavigationBar(
                destinations: const [
                  NavigationDestination(
                    icon: NavIcon(NavGlyph.sessions),
                    selectedIcon: NavIcon(NavGlyph.sessions, selected: true),
                    label: 'Séances',
                  ),
                  NavigationDestination(
                    icon: NavIcon(NavGlyph.students),
                    selectedIcon: NavIcon(NavGlyph.students, selected: true),
                    label: 'Élèves',
                  ),
                  NavigationDestination(
                    icon: NavIcon(NavGlyph.more),
                    selectedIcon: NavIcon(NavGlyph.more, selected: true),
                    label: 'Plus',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Sélectionnée'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  FilterChip(label: const Text('Neutre'), onSelected: (_) {}),
                ],
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Enfants')),
                  ButtonSegment(value: 1, label: Text('Adultes')),
                ],
                selected: const {0},
                onSelectionChanged: (_) {},
              ),
              CounterField(
                label: 'Billes empochées',
                value: 3,
                max: 10,
                onChanged: (_) {},
                decreaseTooltip: 'Une de moins',
                increaseTooltip: 'Une de plus',
              ),
              const ProgressMeter(
                value: 3,
                maximum: 5,
                label: '3 / 5 passages réussis',
              ),
              for (final (emphasis, label) in const [
                (SectionEmphasis.low, 'Mise en avant faible'),
                (SectionEmphasis.medium, 'Mise en avant moyenne'),
                (SectionEmphasis.high, 'Mise en avant forte'),
              ])
                SectionCard(
                  title: label,
                  emphasis: emphasis,
                  child: Text(emphasis.name),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Swatch('accent', brand.accent, brand.onAccent),
                  _Swatch(
                    'accentContainer',
                    brand.accentContainer,
                    brand.onAccentContainer,
                  ),
                  _Swatch('success', status.success, status.onSuccess),
                  _Swatch('attention', status.attention, status.onAttention),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.background, this.foreground);

  final String name;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 168,
    height: 56,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: background,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(name, style: TextStyle(color: foreground)),
  );
}
