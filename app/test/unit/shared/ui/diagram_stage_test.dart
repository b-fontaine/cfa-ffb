import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/diagram_stage.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/rotate_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La plus longue légende du catalogue fait environ 340 caractères.
const _longCaption =
    'Deux bandes : la blanche touche la grande bande du haut (1), puis la '
    "petite bande de droite (2), avant d'atteindre la bille rouge. La "
    'blanche, un peu plus petite que la rouge, est dessinée en creux au '
    'moment de chaque contact. Même visée en demi, depuis un autre endroit '
    ': la bille fantôme est collée à la bille de couleur, sur la ligne de '
    'la poche, côté opposé à la poche.';

const _shortCaption = 'Viser et empocher 6 billes placées en bord de poches.';

const _aspect = 2.0;

void main() {
  Future<List<Size>> pump(
    WidgetTester tester, {
    required Size screen,
    String caption = _shortCaption,
    Widget? badge,
    double textScale = 1,
    double aspect = _aspect,
    double extraHeight = 0,
    double minFigureHeight = 160,
    Key? key,
  }) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final zones = <Size>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: DiagramStage(
            key: key,
            title: 'Presentation: Half ball',
            header: const SizedBox(
              key: ValueKey('header'),
              height: 48,
              child: Text('Illustration 1 of 4'),
            ),
            figureAspect: aspect,
            minFigureHeight: minFigureHeight,
            figure: (context, zone) {
              zones.add(zone);
              final width = zone.width < zone.height * aspect
                  ? zone.width
                  : zone.height * aspect;
              return SizedBox(
                key: const ValueKey('figure'),
                width: width,
                height: width / aspect + extraHeight,
              );
            },
            caption: caption,
            badge: badge,
            previous: const SizedBox(
              key: ValueKey('previous'),
              height: 56,
              child: Text('Previous'),
            ),
            next: const SizedBox(
              key: ValueKey('next'),
              height: 56,
              child: Text('Next'),
            ),
          ),
        ),
      ),
    );
    return zones;
  }

  Rect rectOf(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(ValueKey(key)));

  Rect screenOf(WidgetTester tester) =>
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

  const sizes = <(String, Size, double)>[
    ('1280 x 800', Size(1280, 800), 1),
    ('900 x 600', Size(900, 600), 1),
    ('390 x 844', Size(390, 844), 1),
    ('844 x 390', Size(844, 390), 1),
    ('320 wide, text x1.3', Size(320, 640), 1.3),
  ];

  for (final (name, screen, scale) in sizes) {
    testWidgets(
      'keeps the longest caption whole and the bar visible at $name',
      (tester) async {
        await pump(
          tester,
          screen: screen,
          caption: _longCaption,
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        final bar = rectOf(tester, 'diagram-stage-bottom-bar');
        expect(bar.bottom, lessThanOrEqualTo(screenOf(tester).bottom + 0.5));
        expect(bar.right, lessThanOrEqualTo(screenOf(tester).right + 0.5));

        final panel = find.byKey(const ValueKey('diagram-stage-caption'));
        // Police de test (Ahem) plus large que la vraie : la légende peut
        // dépasser l'écran, elle doit alors être atteignable en fin de course.
        final scroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(DiagramStage),
            matching: find.byType(Scrollable),
          ),
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final caption = tester.getRect(panel);
        final text = tester.getRect(
          find.descendant(of: panel, matching: find.byType(Text)),
        );
        expect(caption.bottom, lessThanOrEqualTo(bar.top + 0.5));
        expect(caption.right, lessThanOrEqualTo(screenOf(tester).right + 0.5));
        expect(text.top, greaterThanOrEqualTo(caption.top - 0.5));
        expect(text.bottom, lessThanOrEqualTo(caption.bottom + 0.5));
      },
    );

    testWidgets('gives the figure at least 160 dp at $name', (tester) async {
      final zones = await pump(
        tester,
        screen: screen,
        caption: _longCaption,
        textScale: scale,
      );

      expect(zones.last.height, greaterThanOrEqualTo(160));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('diagram-stage-figure')))
            .height,
        greaterThanOrEqualTo(160),
      );
    });
  }

  testWidgets('hands the figure what the caption leaves, without scrolling', (
    tester,
  ) async {
    final zones = await pump(tester, screen: const Size(1280, 800));

    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(DiagramStage),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, 0);
    final figure = rectOf(tester, 'diagram-stage-figure');
    final caption = rectOf(tester, 'diagram-stage-caption');
    final bar = rectOf(tester, 'diagram-stage-bottom-bar');
    expect(figure.bottom, lessThanOrEqualTo(caption.top));
    expect(caption.bottom, lessThanOrEqualTo(bar.top + 0.5));
    expect(zones.last.height, closeTo(figure.height, 0.5));
    expect(zones.last.width, closeTo(figure.width, 0.5));
  });

  testWidgets('scrolls rather than crush the figure below 160 dp', (
    tester,
  ) async {
    await pump(tester, screen: const Size(844, 390), caption: _longCaption);

    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(DiagramStage),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(
      tester.getSize(find.byKey(const ValueKey('diagram-stage-figure'))).height,
      160,
    );
  });

  testWidgets('grows and scrolls when the figure cannot fit its zone', (
    tester,
  ) async {
    // Un lecteur dont les commandes dépassent la zone : la légende ne doit
    // pas passer sous le schéma.
    await pump(tester, screen: const Size(390, 844), extraHeight: 400);

    final figure = tester.getRect(find.byKey(const ValueKey('figure')));
    final caption = tester.getRect(
      find.byKey(const ValueKey('diagram-stage-caption')),
    );
    expect(caption.top, greaterThanOrEqualTo(figure.bottom - 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('honors a larger minimum for a figure with controls', (
    tester,
  ) async {
    final zones = await pump(
      tester,
      screen: const Size(844, 390),
      caption: _longCaption,
      minFigureHeight: 224,
    );

    expect(zones.last.height, greaterThanOrEqualTo(224));
  });

  group('text notch thresholds', () {
    Future<(TextStyle, TextTheme)> captionStyle(
      WidgetTester tester,
      Size screen,
    ) async {
      await pump(tester, screen: screen);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('diagram-stage-caption')),
          matching: find.byType(Text),
        ),
      );
      return (
        text.style!,
        Theme.of(tester.element(find.byType(DiagramStage))).textTheme,
      );
    }

    // Largeur : 600 est la première largeur « roomy » ; hauteur : 640.
    final cases = <(Size, bool)>[
      (const Size(599, 800), true),
      (const Size(600, 800), false),
      (const Size(900, 639), true),
      (const Size(900, 640), false),
    ];
    for (final (screen, small) in cases) {
      testWidgets(
        'sets the caption ${small ? 'one notch down' : 'at full size'} at '
        '${screen.width} x ${screen.height}',
        (tester) async {
          final (style, theme) = await captionStyle(tester, screen);

          final expected = small ? theme.bodyLarge! : theme.headlineSmall!;
          expect(style.fontSize, expected.fontSize);
          expect(
            theme.bodyLarge!.fontSize,
            lessThan(theme.headlineSmall!.fontSize!),
          );
        },
      );
    }

    testWidgets('sets the title one notch down below 640 dp of height', (
      tester,
    ) async {
      Future<double?> titleSize(double height) async {
        await pump(tester, screen: Size(900, height));
        return tester
            .widget<Text>(find.text('Presentation: Half ball'))
            .style
            ?.fontSize;
      }

      final at640 = await titleSize(640);
      final theme = Theme.of(tester.element(find.byType(DiagramStage)));
      expect(at640, theme.textTheme.titleLarge!.fontSize);
      final at639 = await titleSize(639);
      expect(at639, theme.textTheme.titleMedium!.fontSize);
    });
  });

  group('compact height threshold', () {
    for (final (height, compact) in [(479.0, true), (480.0, false)]) {
      testWidgets(
        'puts the title ${compact ? 'in' : 'out of'} the bottom bar at '
        '$height dp',
        (tester) async {
          await pump(tester, screen: Size(900, height));

          final title = tester.getRect(find.text('Presentation: Half ball'));
          final bar = rectOf(tester, 'diagram-stage-bottom-bar');
          expect(title.top >= bar.top - 0.5, compact);
        },
      );
    }
  });

  testWidgets('puts the rotate hint outside the students scene', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, screen: const Size(390, 844));

    expect(find.byType(RotateHint), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PresentationScope),
        matching: find.byType(RotateHint),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('puts the title above the figure on a roomy screen', (
    tester,
  ) async {
    await pump(tester, screen: const Size(1280, 800));

    final title = tester.getRect(find.text('Presentation: Half ball'));
    expect(
      title.bottom,
      lessThanOrEqualTo(rectOf(tester, 'diagram-stage-figure').top),
    );
    expect(
      title.top,
      greaterThanOrEqualTo(rectOf(tester, 'header').bottom - 0.5),
    );
  });

  testWidgets('moves the title into the bottom bar on a short screen', (
    tester,
  ) async {
    await pump(tester, screen: const Size(844, 390));

    final title = tester.getRect(find.text('Presentation: Half ball'));
    final bar = rectOf(tester, 'diagram-stage-bottom-bar');
    expect(title.top, greaterThanOrEqualTo(bar.top - 0.5));
    expect(title.bottom, lessThanOrEqualTo(bar.bottom + 0.5));
    // Entre précédent et suivant.
    expect(title.left, greaterThan(rectOf(tester, 'previous').right - 0.5));
    expect(title.right, lessThan(rectOf(tester, 'next').left + 0.5));
  });

  testWidgets('keeps the title as the only header for screen readers', (
    tester,
  ) async {
    for (final screen in const [Size(1280, 800), Size(844, 390)]) {
      final handle = tester.ensureSemantics();
      await pump(tester, screen: screen);

      final headers = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.header == true,
      );
      expect(headers, findsOneWidget);
      expect(
        find.descendant(
          of: headers,
          matching: find.text('Presentation: Half ball'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    }
  });

  testWidgets('tells the figure it is shown to the students', (tester) async {
    await pump(tester, screen: const Size(1280, 800));

    expect(
      PresentationScope.isActive(
        tester.element(find.byKey(const ValueKey('figure'))),
      ),
      isTrue,
    );
  });

  testWidgets('writes the caption large and the badge above it', (
    tester,
  ) async {
    await pump(
      tester,
      screen: const Size(1280, 800),
      badge: const Text('Proposal', key: ValueKey('badge')),
    );

    expect(find.text(_shortCaption), findsOneWidget);
    final badge = rectOf(tester, 'badge');
    final caption = rectOf(tester, 'diagram-stage-caption');
    expect(badge.bottom, lessThanOrEqualTo(caption.top + 0.5));
    expect(
      badge.top,
      greaterThanOrEqualTo(rectOf(tester, 'diagram-stage-figure').bottom - 0.5),
    );
  });

  group('rotate hint', () {
    const hint = 'Rotate the device to enlarge the diagram';

    testWidgets('shows on a phone held upright, above the figure', (
      tester,
    ) async {
      await pump(tester, screen: const Size(390, 844));

      expect(find.text(hint), findsOneWidget);
      expect(
        tester.getRect(find.text(hint)).bottom,
        lessThanOrEqualTo(rectOf(tester, 'diagram-stage-figure').top + 0.5),
      );
    });

    for (final screen in const [
      Size(844, 390),
      Size(1280, 800),
      Size(900, 600),
    ]) {
      testWidgets('is absent in landscape (${screen.width.round()})', (
        tester,
      ) async {
        await pump(tester, screen: screen);

        expect(find.text(hint), findsNothing);
      });
    }

    testWidgets('is absent when the height, not the width, bounds the figure', (
      tester,
    ) async {
      // Portrait, mais un schéma haut et étroit : la hauteur le borne.
      await pump(tester, screen: const Size(600, 900), aspect: 0.4);

      expect(find.text(hint), findsNothing);
    });

    testWidgets('can be dismissed and leaves the figure in place', (
      tester,
    ) async {
      await pump(tester, screen: const Size(390, 844));
      final before = rectOf(tester, 'diagram-stage-figure').width;

      await tester.tap(find.byTooltip('Dismiss the hint'));
      await tester.pumpAndSettle();

      expect(find.text(hint), findsNothing);
      expect(rectOf(tester, 'diagram-stage-figure').width, before);
    });

    testWidgets('comes back with the next step (new key)', (tester) async {
      await pump(tester, screen: const Size(390, 844), key: const ValueKey(1));
      await tester.tap(find.byTooltip('Dismiss the hint'));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsNothing);

      await pump(tester, screen: const Size(390, 844), key: const ValueKey(2));

      expect(find.text(hint), findsOneWidget);
    });
  });

  testWidgets('does not need intrinsic sizes (no IntrinsicHeight)', (
    tester,
  ) async {
    await pump(tester, screen: const Size(1280, 800));

    expect(
      find.descendant(
        of: find.byType(DiagramStage),
        matching: find.byType(IntrinsicHeight),
      ),
      findsNothing,
    );
  });
}
