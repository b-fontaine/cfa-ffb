import 'package:billard_cfa/shared/ui/rotate_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('says to rotate the device, with a rotation icon', (
    tester,
  ) async {
    await pumpUi(tester, RotateHint(onDismiss: () {}));

    expect(
      find.text('Rotate the device to enlarge the diagram'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
  });

  testWidgets('speaks french when the app does', (tester) async {
    await pumpUi(
      tester,
      RotateHint(onDismiss: () {}),
      locale: const Locale('fr'),
    );

    expect(
      find.text("Tournez l'appareil pour agrandir le schéma"),
      findsOneWidget,
    );
  });

  testWidgets('can be dismissed with a 48 dp target', (tester) async {
    var dismissed = 0;
    await pumpUi(tester, RotateHint(onDismiss: () => dismissed++));

    final button = find.byTooltip('Dismiss the hint');
    expect(button, findsOneWidget);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(button);

    expect(dismissed, 1);
  });

  testWidgets('is announced once as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, RotateHint(onDismiss: () {}));

    final data = tester
        .getSemantics(find.text('Rotate the device to enlarge the diagram'))
        .getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('uses the carpet blue container, never red (ADR 0010)', (
    tester,
  ) async {
    await pumpUi(tester, RotateHint(onDismiss: () {}));

    final scheme = Theme.of(tester.element(find.byType(RotateHint)))
        .colorScheme;
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(RotateHint),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, scheme.secondaryContainer);
  });
}
