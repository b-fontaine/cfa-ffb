import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    JourneyMark mark, {
    Locale locale = const Locale('en'),
  }) => pumpUi(
    tester,
    Center(child: JourneyMarker(mark: mark)),
    locale: locale,
  );

  testWidgets('draws a distinct icon for each mark', (tester) async {
    final icons = <IconData?>[];
    for (final mark in JourneyMark.values) {
      await pump(tester, mark);
      icons.add(tester.widget<Icon>(find.byType(Icon)).icon);
    }

    expect(icons, [
      Icons.check_circle,
      Icons.play_circle,
      Icons.radio_button_unchecked,
    ]);
    expect(icons.toSet(), hasLength(3));
  });

  testWidgets('announces its meaning in English and in French', (tester) async {
    final handle = tester.ensureSemantics();
    final english = <String>[];
    for (final mark in JourneyMark.values) {
      await pump(tester, mark);
      english.add(tester.getSemantics(find.byType(JourneyMarker)).label);
    }
    await pump(tester, JourneyMark.next, locale: const Locale('fr'));
    final french = tester.getSemantics(find.byType(JourneyMarker)).label;
    handle.dispose();

    expect(english, ['Done', 'Recommended next', 'Upcoming']);
    expect(french, 'Recommandée ensuite');
  });

  testWidgets('is a target of at least 48 dp', (tester) async {
    await pump(tester, JourneyMark.done);

    final size = tester.getSize(find.byType(JourneyMarker));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('never uses the error colour, whatever the mark', (tester) async {
    for (final mark in JourneyMark.values) {
      await pump(tester, mark);
      final context = tester.element(find.byType(JourneyMarker));
      final error = Theme.of(context).colorScheme.error;

      expect(tester.widget<Icon>(find.byType(Icon)).color, isNot(error));
    }
  });
}
