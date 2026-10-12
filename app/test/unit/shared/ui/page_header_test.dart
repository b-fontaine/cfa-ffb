import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows the title and the subtitle', (tester) async {
    await pumpUi(
      tester,
      const PageHeader(title: 'Planning', subtitle: 'Season 2026'),
    );

    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Season 2026'), findsOneWidget);
  });

  testWidgets('omits the subtitle when absent', (tester) async {
    await pumpUi(tester, const PageHeader(title: 'Planning'));

    expect(find.text('Planning'), findsOneWidget);
    expect(find.byType(PageHeader), findsOneWidget);
    expect(find.text('Season 2026'), findsNothing);
  });

  testWidgets('marks the title as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const PageHeader(title: 'Planning'));

    expect(
      tester.getSemantics(find.text('Planning')),
      isSemantics(label: 'Planning', isHeader: true),
    );
    handle.dispose();
  });
}
