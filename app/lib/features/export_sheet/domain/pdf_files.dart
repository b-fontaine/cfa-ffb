/// Port de sortie d'un document PDF (ADR 0021) : enregistrer un fichier ou
/// l'envoyer à l'impression de la plate-forme. Dart pur ; les implémentations
/// (navigateur, mobile et bureau) sont dans la couche `app`.
///
/// Les octets sont des `List<int>` : le domaine ne connaît pas
/// `dart:typed_data`.
abstract interface class PdfFiles {
  /// Vrai quand la plate-forme sait imprimer un PDF directement (le
  /// navigateur) ; faux ailleurs : l'entrée « Imprimer » est alors masquée.
  bool get canPrint;

  /// Propose d'enregistrer [bytes] sous [fileName] (téléchargement sur le web,
  /// boîte d'enregistrement ailleurs) ; `false` quand l'utilisateur annule,
  /// rien n'est alors écrit.
  Future<bool> save({required String fileName, required List<int> bytes});

  /// Envoie [bytes] à l'impression ; sans effet quand [canPrint] est faux.
  /// [fileName] titre le travail d'impression.
  Future<void> print({required String fileName, required List<int> bytes});
}
