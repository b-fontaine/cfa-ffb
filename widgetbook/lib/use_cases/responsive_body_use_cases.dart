import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Largeur maximale',
  type: ResponsiveBody,
  path: '[Design system]/Composants',
)
Widget buildResponsiveBodyUseCase(BuildContext context) => ResponsiveBody(
  maxWidth: context.knobs.double.slider(
    label: 'largeur max',
    initialValue: 720,
    min: 320,
    max: 1200,
  ),
  child: const DecoratedBox(
    decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide())),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Contenu limité en largeur sur tablette et desktop.'),
    ),
  ),
);
