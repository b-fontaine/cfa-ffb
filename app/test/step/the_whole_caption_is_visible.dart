import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the whole caption is visible
///
/// Le panneau de la légende et son texte sont entiers (ni coupés ni cachés)
/// une fois la scène défilée jusqu'en bas, dans l'écran, au-dessus de la barre
/// basse (F1), et rien ne déborde. Sur un petit écran la scène peut défiler :
/// la légende reste atteignable, jamais tronquée.
Future<void> theWholeCaptionIsVisible(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  final panel = find.byKey(const ValueKey('diagram-stage-caption'));
  expect(panel, findsOneWidget, reason: 'la légende de la scène est absente');
  // La police des tests (Ahem) est plus large que la vraie : la légende peut
  // dépasser l'écran, elle doit alors être atteignable en fin de course.
  final scroll = find.descendant(
    of: find.byKey(const ValueKey('diagram-stage')),
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scroll).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  final rect = tester.getRect(panel);
  final text = tester.getRect(
    find.descendant(of: panel, matching: find.byType(Text)),
  );
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final bar = tester.getRect(
    find.byKey(const ValueKey('presentation-bottom-bar')),
  );
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(screen.width + 0.5));
  expect(
    rect.bottom,
    lessThanOrEqualTo(bar.top + 0.5),
    reason: 'la légende passe sous la barre basse',
  );
  expect(text.top, greaterThanOrEqualTo(rect.top - 0.5));
  expect(text.bottom, lessThanOrEqualTo(rect.bottom + 0.5));
}
