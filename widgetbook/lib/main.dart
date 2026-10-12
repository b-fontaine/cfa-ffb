import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/main.directories.g.dart';

void main() {
  runApp(const WidgetbookApp());
}

/// Catalogue du design system. Les polices de l'application sont servies sous
/// `packages/billard_cfa/…` lorsqu'elle est utilisée comme dépendance.
@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      addons: [
        // L'ordre compte : le premier addon est le plus externe.
        ViewportAddon([
          Viewports.none,
          IosViewports.iPhone13,
          IosViewports.iPadPro11Inches,
          MacosViewports.macbookPro,
        ]),
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(
              name: 'Clair',
              data: AppTheme.light(fontFamily: AppTypography.packageFontFamily),
            ),
            WidgetbookTheme(
              name: 'Sombre',
              data: AppTheme.dark(fontFamily: AppTypography.packageFontFamily),
            ),
          ],
        ),
        LocalizationAddon(
          locales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
        TextScaleAddon(),
        GridAddon(),
        InspectorAddon(),
      ],
    );
  }
}
