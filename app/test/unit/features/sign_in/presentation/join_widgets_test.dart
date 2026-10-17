import 'package:billard_cfa/features/sign_in/presentation/bloc/join_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/join_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

void main() {
  late List<(String, String)> submitted;

  setUp(() => submitted = []);

  Future<void> pump(
    WidgetTester tester,
    JoinState state, {
    String? code,
    Locale locale = const Locale('en'),
  }) => pumpUi(
    tester,
    SingleChildScrollView(
      child: JoinForm(
        state: state,
        initialCode: code,
        onSubmit: (c, n) => submitted.add((c, n)),
      ),
    ),
    locale: locale,
  );

  testWidgets('starts with the code of the link and the draft notice', (
    tester,
  ) async {
    await pump(tester, const JoinState(), code: 'ABCDEFGHJKMN');

    expect(find.text('ABCDEFGHJKMN'), findsOneWidget);
    expect(find.textContaining('Draft notice'), findsOneWidget);
    expect(find.text('Join the club'), findsOneWidget);
  });

  testWidgets('sends the code and the name typed', (tester) async {
    await pump(tester, const JoinState());

    await tester.enterText(find.byType(TextField).at(0), 'abcd-efgh-jkmn');
    await tester.enterText(find.byType(TextField).at(1), 'Camille');
    await tester.tap(find.text('Join the club'));

    expect(submitted, [('abcd-efgh-jkmn', 'Camille')]);
  });

  testWidgets('submitting from the keyboard works, once', (tester) async {
    await pump(tester, const JoinState());
    await tester.enterText(find.byType(TextField).at(1), 'Camille');

    await tester.testTextInput.receiveAction(TextInputAction.done);

    expect(submitted, hasLength(1));
  });

  testWidgets(
    'while submitting the button is inert and the wait is announced',
    (tester) async {
      await pump(tester, const JoinState(status: JoinStatus.submitting));

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Join the club'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Sending…'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, isEmpty);
    },
  );

  testWidgets('a failure is shown with its own message', (tester) async {
    for (final (code, message) in [
      (
        JoinFailureCode.notFound,
        'This code does not exist. Check it and try again.',
      ),
      (
        JoinFailureCode.expired,
        'This invitation has expired. Ask for a new one.',
      ),
      (JoinFailureCode.used, 'This invitation has already been used.'),
      (
        JoinFailureCode.refused,
        'This invitation cannot be used with this account. '
            'You may already belong to this club.',
      ),
      (JoinFailureCode.name, 'Enter your name (40 characters at most).'),
      (
        JoinFailureCode.invalidCode,
        'The invitation code does not have the expected shape: '
            'at least 10 characters, letters A to Z and digits 2 to 7.',
      ),
      (
        JoinFailureCode.unavailable,
        'The service is not responding. Check your connection and try again.',
      ),
    ]) {
      await pump(tester, JoinState(status: JoinStatus.failed, failure: code));
      expect(find.text(message), findsOneWidget, reason: code.name);
    }
  });

  testWidgets('the name field is bounded to what the server accepts', (
    tester,
  ) async {
    await pump(tester, const JoinState());
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).maxLength,
      40,
    );
  });

  testWidgets('the French messages exist for every failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => SingleChildScrollView(
            child: Column(
              children: [
                for (final code in JoinFailureCode.values)
                  Text(joinFailureMessage(AppLocalizations.of(context), code)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Cette invitation a expiré. Demandez-en une nouvelle.'),
      findsOneWidget,
    );
    expect(find.text('Cette invitation a déjà servi.'), findsOneWidget);
  });
}
