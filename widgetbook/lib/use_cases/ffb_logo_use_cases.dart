import 'package:billard_cfa/shared/ui/ffb_logo.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: FfbLogo,
  path: '[Design system]/Composants',
)
Widget buildFfbLogoUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: FfbLogo(
    height: context.knobs.double.slider(
      label: 'hauteur',
      initialValue: 96,
      min: 24,
      max: 200,
    ),
    decorative: context.knobs.boolean(label: 'décoratif'),
  ),
);
