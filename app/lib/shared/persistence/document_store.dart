/// Champs d'un document : valeurs simples (texte, entier, booléen, `DateTime`,
/// `null`), listes et tables de ces valeurs. Aucun type du SDK n'en sort.
typedef Fields = Map<String, Object?>;

/// Valeur d'écriture : « la date du serveur » au moment de l'écriture.
///
/// Les règles Firestore comparent certains champs à `request.time` (création
/// d'une invitation ou d'un member) : le client ne fournit jamais cette date.
final class ServerTimestamp {
  const ServerTimestamp();
}

/// L'unique valeur [ServerTimestamp].
const ServerTimestamp serverTimestamp = ServerTimestamp();

/// Un document lu : son chemin complet (`clubs/c1/members/u1`) et ses champs.
final class StoredDocument {
  const StoredDocument(this.path, this.fields);

  final String path;
  final Fields fields;

  /// Dernier segment du chemin.
  String get id => path.substring(path.lastIndexOf('/') + 1);

  /// Segments du chemin (`['clubs', 'c1', 'members', 'u1']`).
  List<String> get segments => path.split('/');
}

/// Pourquoi une opération du stock de documents a échoué.
enum StoreFailureCode {
  /// Les règles du serveur refusent l'opération.
  permissionDenied,

  /// Le document à mettre à jour n'existe pas.
  notFound,

  /// Réseau ou service injoignable.
  unavailable,

  /// Toute autre erreur du service.
  other,
}

/// Échec d'une opération du stock de documents (traduit du SDK à la
/// frontière, `app/platform/firestore_document_store.dart`).
final class StoreFailure implements Exception {
  const StoreFailure(this.code, [this.detail]);

  final StoreFailureCode code;

  /// Précision technique pour le diagnostic, jamais affichée.
  final String? detail;

  @override
  String toString() =>
      'StoreFailure(${code.name}${detail == null ? '' : ': $detail'})';
}

/// Une écriture d'un lot.
sealed class WriteOp {
  const WriteOp(this.path);

  final String path;
}

/// Crée ou remplace le document.
final class SetOp extends WriteOp {
  const SetOp(super.path, this.fields);

  final Fields fields;
}

/// Fusionne [fields] dans un document qui existe ; échoue (`notFound`) sinon.
final class UpdateOp extends WriteOp {
  const UpdateOp(super.path, this.fields);

  final Fields fields;
}

/// Supprime le document (sans effet s'il n'existe pas).
final class DeleteOp extends WriteOp {
  const DeleteOp(super.path);
}

/// Frontière de Firestore pour les dépôts : lire un document, une collection,
/// une collection de même nom partout (requête de groupe de collections),
/// écrire un **lot atomique**.
///
/// Seul `app/platform/firestore_document_store.dart` touche `cloud_firestore` ;
/// `InMemoryDocumentStore` est le double des tests et des scénarios BDD. Les
/// règles de sécurité vivent côté serveur (`firestore.rules`) : ce port n'en
/// émule aucune.
abstract interface class DocumentStore {
  Future<StoredDocument?> get(String path);

  /// Les documents directement sous [collection] (`clubs/c1/members`),
  /// triés par identifiant.
  Future<List<StoredDocument>> list(String collection);

  /// Les documents de toute collection nommée [collectionId], quel que soit
  /// leur parent, dont le champ [field] vaut [equalTo].
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  });

  /// Applique toutes les écritures ou aucune.
  Future<void> commit(List<WriteOp> operations);
}
