import 'package:billard_cfa/shared/l10n/generated/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sans cas `=0`, le français range 0 avec « un » : « 1 bilan » pour zéro.
/// Tous les compteurs de l'export local et du bandeau (FB7c) sont vérifiés.
void main() {
  final fr = AppLocalizationsFr();
  final counters = <String, String Function(int)>{
    'élève': fr.backupStudents,
    'groupe': fr.backupGroups,
    'saison': fr.backupSeasons,
    'séance donnée': fr.backupSessionRecords,
    'passage': fr.backupAttempts,
    'bilan': fr.backupAssessments,
    'séance planifiée': fr.backupPlannedSessions,
    'bloc acquis': fr.backupBlockAcquisitions,
    'archive de saison close': fr.backupSeasonArchives,
  };

  for (final entry in counters.entries) {
    test('French "${entry.key}" says 0 and 1 correctly', () {
      expect(entry.value(0), startsWith('0 ${entry.key}'));
      expect(entry.value(0), isNot(startsWith('1 ')));
      expect(entry.value(1), startsWith('1 ${entry.key}'));
      expect(entry.value(2), startsWith('2 '));
    });
  }
}
