import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/color_roles_sheet.dart';
import 'package:widgetbook_workspace/support/palette_sheet.dart';
import 'package:widgetbook_workspace/support/typography_sheet.dart';

@widgetbook.UseCase(
  name: 'Couleurs',
  type: PaletteSheet,
  path: '[Design system]/Thème',
)
Widget buildPaletteUseCase(BuildContext context) => const PaletteSheet();

@widgetbook.UseCase(
  name: 'Typographie',
  type: TypographySheet,
  path: '[Design system]/Thème',
)
Widget buildTypographyUseCase(BuildContext context) => const TypographySheet();

@widgetbook.UseCase(
  name: 'Rôles de couleur',
  type: ColorRolesSheet,
  path: '[Design system]/Thème',
)
Widget buildColorRolesUseCase(BuildContext context) => const ColorRolesSheet();
