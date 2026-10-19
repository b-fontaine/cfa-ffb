import 'package:billard_cfa/features/sign_in/presentation/ui/erasure_pending_notice.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Locale locale, VoidCallback onRetry) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light(),
  home: Scaffold(body: ErasurePendingNotice(onRetry: onRetry)),
);

void main() {
  testWidgets('says soberly what to do, in English, and retries', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(_host(const Locale('en'), () => retries++));

    expect(
      find.text(
        'The offline data on this device could not be deleted: close the '
        'other tabs, then try again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry deletion'));
    expect(retries, 1);
  });

  testWidgets('says it in French', (tester) async {
    await tester.pumpWidget(_host(const Locale('fr'), () {}));

    expect(
      find.text(
        "Les données hors ligne de cet appareil n'ont pas pu être effacées : "
        'fermez les autres onglets puis réessayez.',
      ),
      findsOneWidget,
    );
    expect(find.text("Réessayer l'effacement"), findsOneWidget);
  });

  testWidgets('is a live region, so it is announced', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const Locale('en'), () {}));

    expect(
      find.ancestor(
        of: find.byType(Text).first,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
