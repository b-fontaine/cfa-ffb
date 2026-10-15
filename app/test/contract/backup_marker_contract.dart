import 'package:billard_cfa/features/backup_data/domain/backup_marker_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Suite unique du port [BackupMarkerRepository], exécutée contre chaque
/// implémentation.
void backupMarkerContract(
  String label,
  Future<({BackupMarkerRepository repository, Future<void> Function() close})>
  Function()
  open,
) {
  group('$label : contrat de la dernière sauvegarde', () {
    late BackupMarkerRepository repository;
    late Future<void> Function() close;

    setUp(() async {
      final opened = await open();
      repository = opened.repository;
      close = opened.close;
    });
    tearDown(() => close());

    test('knows no backup on a new store', () async {
      expect(await repository.last(), isNull);
    });

    test('keeps the most recent backup', () async {
      await repository.record((
        exportedAt: DateTime(2026, 10, 1, 8),
        attemptCount: 3,
      ));
      await repository.record((
        exportedAt: DateTime(2026, 10, 9, 18, 30),
        attemptCount: 12,
      ));

      final last = await repository.last();

      expect(last!.exportedAt, DateTime(2026, 10, 9, 18, 30));
      expect(last.attemptCount, 12);
    });
  });
}
