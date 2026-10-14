import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

const _adults = [
  PhaseTimelineEntry(label: 'Échauffement', minutes: 10),
  PhaseTimelineEntry(label: 'Notion', minutes: 15),
  PhaseTimelineEntry(label: 'Entraînement', minutes: 45),
  PhaseTimelineEntry(label: 'Jeu', minutes: 35),
  PhaseTimelineEntry(label: 'Bilan', minutes: 15),
];

const _children = [
  PhaseTimelineEntry(label: 'Accueil', minutes: 5),
  PhaseTimelineEntry(label: 'Notion', minutes: 10),
  PhaseTimelineEntry(label: 'Entraînement', minutes: 35),
  PhaseTimelineEntry(label: 'Jeu', minutes: 30),
  PhaseTimelineEntry(label: 'Bilan', minutes: 10),
];

@widgetbook.UseCase(
  name: 'Interactif (adultes, 120 min)',
  type: PhaseTimeline,
  path: _path,
)
Widget buildPhaseTimelineUseCase(BuildContext context) => _Interactive(
  phases: _adults,
  initial:
      context.knobs.int.slider(
        label: 'phase courante',
        initialValue: 2,
        min: 1,
        max: _adults.length,
      ) -
      1,
);

@widgetbook.UseCase(name: 'Enfants (90 min)', type: PhaseTimeline, path: _path)
Widget buildPhaseTimelineChildrenUseCase(BuildContext context) =>
    const _Interactive(phases: _children, initial: 0);

@widgetbook.UseCase(
  name: 'Phases courtes et libellés longs',
  type: PhaseTimeline,
  path: _path,
)
Widget buildPhaseTimelineLongUseCase(BuildContext context) =>
    const _Interactive(
      phases: [
        PhaseTimelineEntry(label: 'Accueil', minutes: 2),
        PhaseTimelineEntry(
          label: 'Notion : le rebond sur la bande',
          minutes: 20,
        ),
        PhaseTimelineEntry(
          label: 'Entraînement approfondi des trajectoires',
          minutes: 40,
        ),
        PhaseTimelineEntry(label: 'Jeu', minutes: 20),
        PhaseTimelineEntry(label: 'Bilan', minutes: 3),
        PhaseTimelineEntry(label: 'Rangement', minutes: 5),
      ],
      initial: 2,
    );

class _Interactive extends StatefulWidget {
  const _Interactive({required this.phases, required this.initial});

  final List<PhaseTimelineEntry> phases;
  final int initial;

  @override
  State<_Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<_Interactive> {
  late int _current = widget.initial;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: PhaseTimeline(
      phases: widget.phases,
      currentIndex: _current,
      onSelected: (index) => setState(() => _current = index),
    ),
  );
}
