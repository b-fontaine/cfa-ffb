import 'package:billard_cfa/shared/l10n/generated/app_localizations_en.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un export local est daté de la dernière modification des **données**, pas
/// de l'heure de l'export : l'avertissement parle de la date des données.
void main() {
  test('French stale-file warning speaks of the date of the data', () {
    expect(
      AppLocalizationsFr().importWarningStaleFile(31),
      'Les dernières données de ce fichier datent d’il y a 31 jours : '
      'ce qui a été saisi ensuite n’y figure pas.',
    );
  });

  test('English stale-file warning speaks of the date of the data', () {
    expect(
      AppLocalizationsEn().importWarningStaleFile(31),
      'The latest data in this file is 31 days old: '
      'anything entered after that is not in it.',
    );
  });
}
