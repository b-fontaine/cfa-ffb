import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/settings_field.dart';
import 'package:billard_cfa/features/manage_settings/presentation/bloc/settings_bloc.dart';
import 'package:billard_cfa/features/manage_settings/presentation/ui/settings_form.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc;

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
}

void main() {
  late _MockBloc bloc;

  Future<void> pumpForm(
    WidgetTester tester,
    SettingsState state, {
    Locale locale = const Locale('en'),
  }) async {
    bloc = _MockBloc();
    whenListen(bloc, const Stream<SettingsState>.empty(), initialState: state);
    await pumpUi(
      tester,
      BlocProvider<SettingsBloc>.value(
        value: bloc,
        child: const SingleChildScrollView(child: SettingsForm()),
      ),
      locale: locale,
    );
  }

  SettingsState editing({ClubSettings? draft, SettingsStatus? status}) =>
      SettingsState(
        status: status ?? SettingsStatus.editing,
        saved: ClubSettings.defaults,
        draft: draft ?? ClubSettings.defaults,
      );

  testWidgets('shows the five settings and the retroactivity sentence', (
    tester,
  ) async {
    await pumpForm(tester, editing());

    expect(
      find.textContaining('does not change the passes already entered'),
      findsOneWidget,
    );
    expect(find.byType(Semantics), findsWidgets);
    for (final label in [
      'Successful passes to validate an exercise',
      'Consecutive failures before an alert',
      'Sessions without practice before a recall',
      'Group failure share (%) that recalls an exercise',
      'Days before a backup reminder',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('a counter reports the field and the new value', (tester) async {
    await pumpForm(tester, editing());

    await tester.tap(find.byTooltip('More successful passes required'));

    verify(
      () => bloc.add(
        const SettingsEvent.changed(
          field: SettingsField.passesRequired,
          value: 6,
        ),
      ),
    ).called(1);
  });

  testWidgets('save is disabled until the form is modified', (tester) async {
    await pumpForm(tester, editing());
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save settings'),
          )
          .onPressed,
      isNull,
    );

    await pumpForm(
      tester,
      editing(draft: ClubSettings.defaults.copyWith(passesRequired: 3)),
    );
    expect(find.text('Unsaved changes.'), findsOneWidget);
    await _tapText(tester, 'Save settings');

    verify(() => bloc.add(const SettingsEvent.saveRequested())).called(1);
  });

  testWidgets('reset needs a confirmation', (tester) async {
    await pumpForm(tester, editing());

    await _tapText(tester, 'Restore default values');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Cancel');
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(const SettingsEvent.resetConfirmed()));

    await _tapText(tester, 'Restore default values');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Confirm');
    await tester.pumpAndSettle();
    verify(() => bloc.add(const SettingsEvent.resetConfirmed())).called(1);
  });

  testWidgets('shows a refusal as a message and keeps the draft', (
    tester,
  ) async {
    await pumpForm(
      tester,
      SettingsState(
        status: SettingsStatus.failed,
        saved: ClubSettings.defaults,
        draft: ClubSettings.defaults.copyWith(alertThreshold: 4),
        failure: const InvariantViolation(InvariantCode.invalidRules),
      ),
    );

    expect(
      find.text('These settings are not accepted: nothing was saved.'),
      findsOneWidget,
    );
  });

  testWidgets('announces the saved state in a live region', (tester) async {
    await pumpForm(tester, editing(status: SettingsStatus.saved));

    final message = find.text('Settings saved.');
    expect(message, findsOneWidget);
    expect(
      find.ancestor(
        of: message,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the counters are at least 48 dp', (tester) async {
    await pumpForm(tester, editing());

    for (final tooltip in [
      'Fewer failures before an alert',
      'More days before a reminder',
    ]) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('is in French on a French device', (tester) async {
    await pumpForm(tester, editing(), locale: const Locale('fr'));

    expect(find.text('Validation des exercices'), findsOneWidget);
    expect(find.text('Enregistrer les réglages'), findsOneWidget);
  });
}
