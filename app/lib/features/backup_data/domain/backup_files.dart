/// Port d'accès aux fichiers de sauvegarde de l'appareil : téléchargement ou
/// enregistrement (export) et sélection d'un fichier (import).
abstract interface class BackupFiles {
  /// Propose d'enregistrer [content] sous [fileName] ; `false` si l'utilisateur
  /// annule.
  Future<bool> save({required String fileName, required String content});

  /// Fait choisir un fichier et renvoie son texte ; `null` si l'utilisateur
  /// annule. Un fichier qui n'est pas du texte UTF-8 donne un texte vide
  /// (refusé ensuite comme sauvegarde illisible).
  Future<String?> pick();
}
