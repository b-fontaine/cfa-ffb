import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

@widgetbook.UseCase(name: 'Interactif', type: PassDots, path: _path)
Widget buildPassDotsUseCase(BuildContext context) {
  final total = context.knobs.int.slider(label: 'essais', initialValue: 5);
  return _InteractivePassDots(
    key: ValueKey(total),
    total: total,
    readOnly: context.knobs.boolean(label: 'lecture seule'),
  );
}

@widgetbook.UseCase(name: 'Lecture seule', type: PassDots, path: _path)
Widget buildPassDotsReadOnlyUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: PassDots(
    value: [true, true, false, true, false],
    total: 5,
    readOnly: true,
  ),
);

@widgetbook.UseCase(name: 'Désactivé', type: PassDots, path: _path)
Widget buildPassDotsDisabledUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: PassDots(value: [true, false, true], total: 5),
);

@widgetbook.UseCase(
  name: 'Vingt essais (retour à la ligne)',
  type: PassDots,
  path: _path,
)
Widget buildPassDotsManyUseCase(BuildContext context) =>
    const _InteractivePassDots(total: 20);

class _InteractivePassDots extends StatefulWidget {
  const _InteractivePassDots({
    required this.total,
    this.readOnly = false,
    super.key,
  });

  final int total;
  final bool readOnly;

  @override
  State<_InteractivePassDots> createState() => _InteractivePassDotsState();
}

class _InteractivePassDotsState extends State<_InteractivePassDots> {
  List<bool> _value = const [];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: PassDots(
      value: _value,
      total: widget.total,
      readOnly: widget.readOnly,
      onChanged: (next) => setState(() => _value = next),
    ),
  );
}
