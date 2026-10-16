import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Marqueur de parcours',
  type: JourneyMarker,
  path: '[Design system]/Composants',
)
Widget buildJourneyMarkerUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: JourneyMarker(
    mark: context.knobs.object.dropdown<JourneyMark>(
      label: 'marqueur',
      options: JourneyMark.values,
      labelBuilder: (value) => value.name,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Les trois marqueurs',
  type: JourneyMarker,
  path: '[Design system]/Composants',
)
Widget buildJourneyMarkersUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Row(
    children: [
      for (final mark in JourneyMark.values) JourneyMarker(mark: mark),
    ],
  ),
);
