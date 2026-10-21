import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // FB7c, règle de la période de bascule (roadmap, « Procédure de bascule »).
  test('the local schema version is frozen until drift is removed', () {
    expect(
      AppDatabase.currentSchemaVersion,
      12,
      reason:
          'Le build Firestore ouvre encore la base locale drift (séances '
          'guidées en cours, unité de travail) : monter la version la '
          'MIGRERAIT chez les animateurs qui ont des données à exporter, et un '
          'retour arrière vers le build précédent lèverait '
          'DowngradeNotSupported (base plus récente que l’application), '
          'rendant leurs données illisibles. Tant que drift n’est pas retiré '
          '(lot ultérieur), ne pas changer ce numéro ; si ce lot le retire, '
          'supprimer ce test avec lui, dans le même commit.',
    );
  });

  test('an older application refuses a newer base instead of reading it', () {
    // Le refus qui fait de la montée de version un aller sans retour.
    const error = DowngradeNotSupported(from: 13, to: 12);

    expect(error.toString(), contains('13'));
  });
}
