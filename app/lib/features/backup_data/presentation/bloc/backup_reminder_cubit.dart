import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/features/backup_data/domain/check_backup_reminder.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Rappel de sauvegarde de l'accueil : évalué à l'ouverture de l'écran,
/// silencieux tant que la règle ne dit rien.
@injectable
class BackupReminderCubit extends Cubit<BackupReminder> {
  BackupReminderCubit(this._check) : super(const NoBackupReminder());

  final CheckBackupReminder _check;

  Future<void> check() async {
    final reminder = await _check();
    if (!isClosed) emit(reminder);
  }
}
