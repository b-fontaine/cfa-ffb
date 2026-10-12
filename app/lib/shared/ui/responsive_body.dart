import 'package:flutter/material.dart';

/// Limite la largeur du contenu : confortable sur tablette, desktop et web,
/// pleine largeur sur smartphone.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({required this.child, this.maxWidth = 720, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
