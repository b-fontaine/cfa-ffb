import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('enlarges the text scale of its content', (tester) async {
    late double inside;
    late double outside;
    await pumpUi(
      tester,
      Builder(
        builder: (context) {
          outside = MediaQuery.textScalerOf(context).scale(10);
          return PresentationScope(
            child: Builder(
              builder: (context) {
                inside = MediaQuery.textScalerOf(context).scale(10);
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );

    expect(outside, 10);
    expect(inside, closeTo(15, 1e-9));
  });

  testWidgets('tells its content that it is shown to students', (tester) async {
    late bool inside;
    late bool outside;
    await pumpUi(
      tester,
      Builder(
        builder: (context) {
          outside = PresentationScope.isActive(context);
          return PresentationScope(
            child: Builder(
              builder: (context) {
                inside = PresentationScope.isActive(context);
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );

    expect(outside, isFalse);
    expect(inside, isTrue);
  });

  testWidgets('writes the caption large, for the students', (tester) async {
    await pumpUi(
      tester,
      const PresentationScope(
        caption: 'Demi-bille : la blanche couvre la moitié.',
        child: Text('schéma'),
      ),
    );

    expect(
      find.text('Demi-bille : la blanche couvre la moitié.'),
      findsOneWidget,
    );
    expect(find.text('schéma'), findsOneWidget);
  });

  testWidgets('is announced as an enlarged display', (tester) async {
    await pumpUi(
      tester,
      const PresentationScope(child: Text('schéma')),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel(RegExp('Affichage agrandi pour les élèves')),
      findsOneWidget,
    );
  });

  test('refuses a scale below 1', () {
    expect(
      () => PresentationScope(scale: 0.5, child: const SizedBox()),
      throwsAssertionError,
    );
  });

  testWidgets('keeps a wide child inside the screen without overflow', (
    tester,
  ) async {
    await pumpUi(
      tester,
      PresentationScope(
        caption: 'Une légende assez longue pour passer à la ligne ' * 3,
        child: Text('Un contenu large ' * 8),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  group('transparent', () {
    Finder surfaceFill(ColorScheme scheme) => find.byWidgetPredicate(
      (widget) => widget is ColoredBox && widget.color == scheme.surface,
    );

    testWidgets('paints the surface by default, as before', (tester) async {
      await pumpUi(
        tester,
        const PresentationScope(caption: 'Légende', child: Text('schéma')),
      );

      final scheme = Theme.of(tester.element(find.text('schéma'))).colorScheme;
      expect(surfaceFill(scheme), findsOneWidget);
      expect(find.byType(PresentationCaption), findsNothing);
    });

    testWidgets('lets the background show through', (tester) async {
      await pumpUi(
        tester,
        const PresentationScope(transparent: true, child: Text('schéma')),
      );

      final scheme = Theme.of(tester.element(find.text('schéma'))).colorScheme;
      expect(surfaceFill(scheme), findsNothing);
    });

    testWidgets('writes the caption on a surface panel', (tester) async {
      await pumpUi(
        tester,
        const PresentationScope(
          transparent: true,
          caption: 'Légende',
          child: Text('schéma'),
        ),
      );

      final panel = find.byType(PresentationCaption);
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('Légende')),
        findsOneWidget,
      );
    });

    testWidgets('keeps the enlarged text and the marker', (tester) async {
      late double inside;
      late bool active;
      await pumpUi(
        tester,
        PresentationScope(
          transparent: true,
          child: Builder(
            builder: (context) {
              inside = MediaQuery.textScalerOf(context).scale(10);
              active = PresentationScope.isActive(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(inside, closeTo(15, 1e-9));
      expect(active, isTrue);
    });

    testWidgets('takes the padding it is given', (tester) async {
      await pumpUi(
        tester,
        const PresentationScope(
          transparent: true,
          padding: EdgeInsets.zero,
          child: SizedBox(key: ValueKey('inner'), height: 10),
        ),
      );

      expect(tester.getSize(find.byType(PresentationScope)).height, 10);
    });
  });
}
