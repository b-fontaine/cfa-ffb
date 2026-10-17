import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/ui/session_tag_picker.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

@widgetbook.UseCase(name: 'Interactif', type: SessionTagPicker, path: _path)
Widget buildSessionTagPickerUseCase(BuildContext context) =>
    const _InteractivePicker();

@widgetbook.UseCase(
  name: 'Deux étiquettes choisies',
  type: SessionTagPicker,
  path: _path,
)
Widget buildSessionTagPickerSelectedUseCase(BuildContext context) =>
    const _InteractivePicker(initial: {SessionTag.tooLong, SessionTag.toRedo});

@widgetbook.UseCase(name: 'Lecture seule', type: SessionTagPicker, path: _path)
Widget buildSessionTagPickerReadOnlyUseCase(BuildContext context) =>
    const Padding(
      padding: EdgeInsets.all(16),
      child: SessionTagPicker(selected: {SessionTag.gameAppreciated}),
    );

class _InteractivePicker extends StatefulWidget {
  const _InteractivePicker({this.initial = const {}});

  final Set<SessionTag> initial;

  @override
  State<_InteractivePicker> createState() => _InteractivePickerState();
}

class _InteractivePickerState extends State<_InteractivePicker> {
  late Set<SessionTag> _selected = widget.initial;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: SessionTagPicker(
      selected: _selected,
      onChanged: (tags) => setState(() => _selected = tags),
    ),
  );
}
