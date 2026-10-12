import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: AudienceBadge,
  path: '[Design system]/Composants',
)
Widget buildAudienceBadgeUseCase(BuildContext context) => Center(
  child: AudienceBadge(
    kind: context.knobs.object.dropdown<AudienceKind>(
      label: 'public',
      options: AudienceKind.values,
      labelBuilder: (value) => value.name,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Les deux publics',
  type: AudienceBadge,
  path: '[Design system]/Composants',
)
Widget buildAudienceBadgesUseCase(BuildContext context) => Center(
  child: Wrap(
    spacing: 12,
    children: [
      for (final kind in AudienceKind.values) AudienceBadge(kind: kind),
    ],
  ),
);
