import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: PageHeader,
  path: '[Design system]/Composants',
)
Widget buildPageHeaderUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: PageHeader(
    title: context.knobs.string(label: 'titre', initialValue: 'Mes élèves'),
    subtitle: context.knobs.stringOrNull(
      label: 'sous-titre',
      initialValue: 'Saison 2026-2027',
    ),
  ),
);
