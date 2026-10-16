import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows the header and every child', (tester) async {
    await pumpUi(
      tester,
      const ScrollPage(
        title: 'Title',
        subtitle: 'Sub',
        children: [Text('one'), Text('two')],
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('offers a back action of at least 48 dp', (tester) async {
    var back = 0;
    await pumpUi(
      tester,
      ScrollPage(
        title: 'Title',
        onBack: () => back++,
        backLabel: 'Back',
        children: const [],
      ),
    );

    await tester.tap(find.text('Back'));

    expect(back, 1);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('scrolls a long content', (tester) async {
    await pumpUi(
      tester,
      ScrollPage(
        title: 'Title',
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 80, child: Text('row $i')),
        ],
      ),
    );

    await tester.scrollUntilVisible(find.text('row 39'), 200);

    expect(find.text('row 39'), findsOneWidget);
  });

  testWidgets('places actions at the end of the back row', (tester) async {
    await pumpUi(
      tester,
      ScrollPage(
        title: 'Title',
        onBack: () {},
        backLabel: 'Back',
        actions: const [Icon(Icons.more_vert, key: ValueKey('action'))],
        children: const [],
      ),
    );

    final back = tester.getRect(find.text('Back'));
    final action = tester.getRect(find.byKey(const ValueKey('action')));
    expect(action.left, greaterThan(back.right));
    expect((action.center.dy - back.center.dy).abs(), lessThan(24));
  });

  testWidgets('shows actions even without a back button', (tester) async {
    await pumpUi(
      tester,
      const ScrollPage(
        title: 'Title',
        actions: [Icon(Icons.more_vert, key: ValueKey('action'))],
        children: [],
      ),
    );

    expect(find.byKey(const ValueKey('action')), findsOneWidget);
  });

  testWidgets('limits the content to 720 dp by default', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      const ScrollPage(
        title: 'Title',
        children: [SizedBox(key: ValueKey('wide'), height: 20)],
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('wide'))).width, 688);
  });

  testWidgets('widens the content with maxWidth', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      const ScrollPage(
        title: 'Title',
        maxWidth: 1100,
        children: [SizedBox(key: ValueKey('wide'), height: 20)],
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('wide'))).width, 1068);
  });
}
