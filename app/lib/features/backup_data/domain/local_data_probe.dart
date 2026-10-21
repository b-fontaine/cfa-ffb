import 'package:billard_cfa/shared/lib/local_data_inventory.dart';

/// Port : ce que contient la base locale de l'appareil, relevé **sans rien
/// écrire** (FB7c). En production, le relevé est fait au démarrage, avant
/// que l'application n'ouvre (ni ne crée, ni ne migre) la base.
abstract interface class LocalDataProbe {
  Future<LocalDataInventory> inspect();
}
