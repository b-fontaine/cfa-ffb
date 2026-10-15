import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/domain/check_backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_reminder_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheck extends Mock implements CheckBackupReminder;

void main() {
  blocTest<BackupReminderCubit, BackupReminder>(
    'starts silent and publishes the reminder once checked',
    build: () {
      final check = _MockCheck();
      when(check.call).thenAnswer((_) async => const StaleBackup(40));
      return BackupReminderCubit(check);
    },
    act: (cubit) => cubit.check(),
    expect: () => [isA<StaleBackup>()],
  );
}
