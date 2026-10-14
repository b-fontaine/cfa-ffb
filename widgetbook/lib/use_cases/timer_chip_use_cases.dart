import 'package:billard_cfa/shared/ui/timer_chip.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

@widgetbook.UseCase(name: 'Interactif', type: TimerChip, path: _path)
Widget buildTimerChipUseCase(BuildContext context) => _TimerStates(
  seconds: context.knobs.int.slider(
    label: 'secondes restantes',
    initialValue: 300,
    min: -300,
    max: 900,
  ),
);

@widgetbook.UseCase(
  name: 'Les trois tons (neutre, attention, dépassé)',
  type: TimerChip,
  path: _path,
)
Widget buildTimerChipTonesUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      _StaticChip(seconds: 600),
      _StaticChip(seconds: 45),
      _StaticChip(seconds: -75),
    ],
  ),
);

@widgetbook.UseCase(name: 'En pause', type: TimerChip, path: _path)
Widget buildTimerChipPausedUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: _StaticChip(seconds: 600, running: false),
);

class _StaticChip extends StatelessWidget {
  const _StaticChip({required this.seconds, this.running = true});

  final int seconds;
  final bool running;

  @override
  Widget build(BuildContext context) => TimerChip(
    remaining: Duration(seconds: seconds),
    running: running,
    onToggle: () {},
  );
}

class _TimerStates extends StatefulWidget {
  const _TimerStates({required this.seconds});

  final int seconds;

  @override
  State<_TimerStates> createState() => _TimerStatesState();
}

class _TimerStatesState extends State<_TimerStates> {
  bool _running = true;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: TimerChip(
      remaining: Duration(seconds: widget.seconds),
      running: _running,
      onToggle: () => setState(() => _running = !_running),
    ),
  );
}
