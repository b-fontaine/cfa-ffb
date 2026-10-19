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

/// Valeur d'écriture : ajoute [values] à la liste du champ, sans doublon,
/// **atomiquement côté serveur** (aucune lecture préalable, deux écritures
/// concurrentes s'additionnent au lieu de s'écraser).
final class ArrayUnion {
  const ArrayUnion(this.values);

  final List<Object?> values;
}

/// Valeur d'écriture : retire [values] de la liste du champ, atomiquement
/// côté serveur (sans effet pour une valeur absente).
final class ArrayRemove {
  const ArrayRemove(this.values);

  final List<Object?> values;
}

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
  /// L'opération demandée n'existe pas dans ce contexte (une création
  /// conditionnelle dans une unité de travail : voir `ClubStore`).
  unsupported,

  /// Les règles du serveur refusent l'opération.
  permissionDenied,

  /// Le serveur exige une condition absente (`failed-precondition`) : le plus
  /// souvent un index composite non déployé. Permanent tant que la
  /// configuration ne change pas : réessayer n'y change rien.
  failedPrecondition,

  /// Le document à mettre à jour n'existe pas.
  notFound,

  /// Plus de [maxBatchWrites] écritures dans un lot atomique : refusé avant
  /// toute écriture (un lot de Firestore en accepte 500 au plus).
  batchTooLarge,

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

/// Crée ou remplace le document ; avec [merge], crée le document ou fusionne
/// [fields] dans celui qui existe (les autres champs sont conservés).
final class SetOp extends WriteOp {
  const SetOp(super.path, this.fields, {this.merge = false});

  final Fields fields;
  final bool merge;
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

/// Filtre d'une requête sur une collection : un seul champ, un seul
/// opérateur. Ni tri ni filtre composé : un index composite n'est donc jamais
/// nécessaire (et `tool/check_indexes.dart` le garde).
sealed class QueryFilter {
  const QueryFilter(this.field);

  final String field;
}

/// Le champ vaut [value].
final class FieldEquals extends QueryFilter {
  const FieldEquals(super.field, this.value);

  final Object? value;
}

/// Le champ est une liste qui contient au moins une des [values] (Firestore
/// accepte 30 valeurs au plus ; au-delà, l'appelant découpe).
final class FieldArrayContainsAny extends QueryFilter {
  const FieldArrayContainsAny(super.field, this.values);

  final List<Object?> values;
}

/// Plusieurs égalités sur des champs **différents**, toutes exigées. Sans
/// tri ni inégalité : Firestore sert ces requêtes par fusion des index à
/// champ unique, **aucun index composite** n'est à déclarer. Sert à prouver
/// aux règles le groupe d'un passage (`groupId`) tout en le restreignant à un
/// élève ou à une séance.
final class AllEqual extends QueryFilter {
  AllEqual(this.clauses) : super(clauses.first.field);

  final List<FieldEquals> clauses;
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

  /// Lit [path] **dans le cache local seulement** : jamais d'attente du
  /// réseau, et `null` si le document n'y est pas (même s'il existe sur le
  /// serveur). C'est la lecture des écritures **hors ligne** : lire d'abord un
  /// document absent du cache échoue hors ligne (`unavailable`) alors que
  /// l'écriture, elle, réussit (FB5, ADR 0024 décision 1). Une réponse `null`
  /// n'affirme donc jamais l'absence : l'invariant d'une écriture qui s'appuie
  /// dessus est porté par les règles, pas par cette lecture.
  Future<StoredDocument?> peek(String path);

  /// Les documents directement sous [collection] (`clubs/c1/members`),
  /// triés par identifiant.
  Future<List<StoredDocument>> list(String collection);

  /// Les documents directement sous [collection] qui satisfont [filter],
  /// triés par identifiant. Sans index à déclarer (un seul champ).
  Future<List<StoredDocument>> query(String collection, QueryFilter filter);

  /// Les documents de toute collection nommée [collectionId], quel que soit
  /// leur parent, dont le champ [field] vaut [equalTo].
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  });

  /// Crée le document [path] **s'il est absent**, atomiquement côté serveur
  /// (lecture et écriture d'une même transaction) ; rend `false`, sans rien
  /// écrire, s'il existe déjà. C'est la seule façon d'écrire une date de
  /// création sans risque : une écriture qui peut être une mise à jour ne
  /// l'envoie jamais (les règles figent `createdAt`).
  Future<bool> createIfAbsent(String path, Fields fields);

  /// Applique toutes les écritures ou aucune ; au plus [maxBatchWrites] :
  /// au-delà, [StoreFailureCode.batchTooLarge] sans rien écrire.
  Future<void> commit(List<WriteOp> operations);
}

/// Écritures d'un lot au plus (limite de Firestore).
const int maxBatchWrites = 500;

/// Refuse un lot de plus de [maxBatchWrites] écritures.
void checkBatchSize(List<WriteOp> operations) {
  if (operations.length > maxBatchWrites) {
    throw StoreFailure(
      StoreFailureCode.batchTooLarge,
      '${operations.length} writes > $maxBatchWrites',
    );
  }
}
