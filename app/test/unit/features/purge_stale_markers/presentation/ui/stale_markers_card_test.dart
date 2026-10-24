import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_state.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/ui/stale_markers_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../shared/ui/pump_ui.dart';

StaleMarkersState _finished(
  StaleMarkerPurgeStatus status,
  int removed, [
  ServiceFailureCode? code,
]) => StaleMarkersState.finished(
  StaleMarkerPurgeResult(
    status: status,
    removed: removed,
    failure: code == null ? null : ServiceFailure(code),
  ),
);

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  Future<List<void>> pump(
    WidgetTester tester, {
    StaleMarkersState state = const StaleMarkersState.idle(),
    Locale locale = const Locale('en'),
  }) async {
    final taps = <void>[];
    await pumpUi(
      tester,
      SingleChildScrollView(
        child: StaleMarkersCard(state: state, onPurge: () => taps.add(null)),
      ),
      locale: locale,
    );
    return taps;
  }

  group('StaleMarkersCard', () {
    testWidgets('says what a marker is, the 90 days and the re-import risk', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(en.staleMarkersTitle), findsOneWidget);
      expect(find.text(en.staleMarkersBody(90)), findsOneWidget);
      expect(find.textContaining('more than 90 days'), findsOneWidget);
      expect(
        find.widgetWithText(AppAlert, en.staleMarkersWarning),
        findsOneWidget,
      );
    });

    testWidgets('the same texts exist in French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.textContaining('plus de 90 jours'), findsOneWidget);
      expect(
        find.textContaining('rétablir les élèves effacés'),
        findsOneWidget,
      );
      expect(find.text(fr.staleMarkersAction), findsOneWidget);
    });

    testWidgets('the button runs the purge', (tester) async {
      final taps = await pump(tester);

      await tester.tap(find.text(en.staleMarkersAction));

      expect(taps, hasLength(1));
    });

    testWidgets('while running: progress, and the button is off', (
      tester,
    ) async {
      final taps = await pump(tester, state: const StaleMarkersState.running());

      expect(find.text(en.staleMarkersRunning), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text(en.staleMarkersAction));
      expect(taps, isEmpty);
    });

    testWidgets('completed: how many were removed, or none', (tester) async {
      await pump(tester, state: _finished(StaleMarkerPurgeStatus.completed, 3));
      expect(find.text('3 abandoned markers removed.'), findsOneWidget);

      await pump(tester, state: _finished(StaleMarkerPurgeStatus.completed, 0));
      expect(find.text('No abandoned marker.'), findsOneWidget);
    });

    testWidgets('paused: the daily ceiling, and tomorrow', (tester) async {
      await pump(tester, state: _finished(StaleMarkerPurgeStatus.paused, 400));

      expect(
        find.widgetWithText(AppAlert, en.staleMarkersPaused(400)),
        findsOneWidget,
      );
    });

    testWidgets('interrupted: the failure, what was done, and run again', (
      tester,
    ) async {
      final taps = await pump(
        tester,
        state: _finished(
          StaleMarkerPurgeStatus.interrupted,
          2,
          ServiceFailureCode.unavailable,
        ),
      );

      expect(
        find.widgetWithText(AppAlert, en.failServiceUnavailable),
        findsOneWidget,
      );
      expect(find.text(en.staleMarkersStopped(2)), findsOneWidget);
      await tester.tap(find.text(en.staleMarkersAction));
      expect(taps, hasLength(1));
    });

    testWidgets('refused: the refusal is said', (tester) async {
      await pump(
        tester,
        state: _finished(
          StaleMarkerPurgeStatus.failed,
          0,
          ServiceFailureCode.denied,
        ),
      );

      expect(
        find.widgetWithText(AppAlert, en.failServiceDenied),
        findsOneWidget,
      );
      expect(find.text(en.staleMarkersStopped(0)), findsOneWidget);
    });
  });
}
