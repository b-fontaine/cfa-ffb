import 'package:billard_cfa/features/sync_status/domain/sync_state.dart';
import 'package:billard_cfa/features/sync_status/presentation/ui/sync_status_chip.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(SyncState state, {VoidCallback? onAck, Locale? locale}) =>
    MaterialApp(
      locale: locale ?? const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SyncStatusChip(
            state: state,
            onAcknowledgeFailure: onAck ?? () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('up to date', (tester) async {
    await tester.pumpWidget(_host(SyncState.upToDate));

    expect(find.text('Up to date'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('offline with nothing to send', (tester) async {
    await tester.pumpWidget(
      _host(const SyncState(phase: SyncPhase.offline, offline: true)),
    );

    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('pending shows the number of batches, online or offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SyncState(phase: SyncPhase.pending, pending: 2)),
    );
    expect(find.text('Waiting to send (2)'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        const SyncState(phase: SyncPhase.pending, pending: 2, offline: true),
      ),
    );
    expect(find.text('Offline, waiting to send (2)'), findsOneWidget);
  });

  testWidgets('a refused send says so soberly and offers its action', (
    tester,
  ) async {
    var acknowledged = 0;
    await tester.pumpWidget(
      _host(
        const SyncState(phase: SyncPhase.failed),
        onAck: () => acknowledged++,
      ),
    );

    expect(
      find.text('A change could not be saved and was undone on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    expect(acknowledged, 1);
  });

  testWidgets('French labels', (tester) async {
    await tester.pumpWidget(
      _host(
        const SyncState(phase: SyncPhase.pending, pending: 3),
        locale: const Locale('fr'),
      ),
    );

    expect(find.text('Envoi en attente (3)'), findsOneWidget);
  });

  testWidgets('the region is live and the icon is not announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const SyncState(phase: SyncPhase.pending, pending: 1)),
    );

    final node = tester.getSemantics(find.text('Waiting to send (1)'));
    // La région vive est nommée « Synchronization », puis dit l'état.
    expect(node.label, 'Synchronization\nWaiting to send (1)');
    expect(
      find.ancestor(
        of: find.text('Waiting to send (1)'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the live region is announced in French as well', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const SyncState(phase: SyncPhase.pending, pending: 1),
        locale: const Locale('fr'),
      ),
    );

    expect(
      tester.getSemantics(find.text('Envoi en attente (1)')).label,
      'Synchronisation\nEnvoi en attente (1)',
    );
    handle.dispose();
  });

  testWidgets('no state is red: normal states use the carpet-blue roles', (
    tester,
  ) async {
    for (final state in const [
      SyncState(phase: SyncPhase.offline, offline: true),
      SyncState(phase: SyncPhase.pending, pending: 1),
    ]) {
      await tester.pumpWidget(_host(state));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(SyncStatusChip),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final colors = Theme.of(tester.element(find.byType(SyncStatusChip)))
          .colorScheme;

      expect(
        (box.decoration as BoxDecoration).color,
        colors.secondaryContainer,
      );
    }
  });
}
