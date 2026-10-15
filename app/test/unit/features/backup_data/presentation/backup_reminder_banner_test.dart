import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/backup_reminder_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester,
    BackupReminder reminder, {
    void Function()? onBackup,
  }) => pumpUi(
    tester,
    BackupReminderBanner(reminder: reminder, onBackup: onBackup ?? () {}),
  );

  testWidgets('shows nothing without reminder', (tester) async {
    await pumpBanner(tester, const NoBackupReminder());

    expect(find.text('Back up now'), findsNothing);
  });

  testWidgets('says the data was never backed up', (tester) async {
    await pumpBanner(tester, const NeverBackedUp());

    expect(find.textContaining('never been backed up'), findsOneWidget);
  });

  testWidgets('gives the age of a stale backup', (tester) async {
    await pumpBanner(tester, const StaleBackup(34));

    expect(find.textContaining('34 days ago'), findsOneWidget);
  });

  testWidgets('counts the passes entered since the backup', (tester) async {
    await pumpBanner(tester, const NewPassesSinceBackup(1));

    expect(find.textContaining('1 pass entered'), findsOneWidget);
  });

  testWidgets('the action is at least 48 dp high', (tester) async {
    await pumpBanner(tester, const NeverBackedUp());

    final size = tester.getSize(
      find.widgetWithText(FilledButton, 'Back up now'),
    );

    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the action leads to the backup', (tester) async {
    var tapped = 0;
    await pumpBanner(tester, const NeverBackedUp(), onBackup: () => tapped++);

    await tester.tap(find.text('Back up now'));

    expect(tapped, 1);
  });
}
