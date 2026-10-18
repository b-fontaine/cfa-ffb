import 'dart:convert';
import 'dart:io';

/// Garde-fou « index Firestore » : toute requête du code qui exige un index
/// doit le trouver dans `firestore.indexes.json`. Firestore ne le dit qu'à
/// l'exécution (`failed-precondition`) ; ce contrôle statique le dit avant.
///
/// Reconnu dans `lib/` (hors fichiers générés) :
/// - `collectionGroup('c', field: 'f', …)` (port `DocumentStore`) ou
///   `collectionGroup('c').where('f', …)` (SDK) : exige une **exemption de
///   champ** `c.f` à portée `COLLECTION_GROUP` (`fieldOverrides`) ;
/// - une requête composée : `where('a', …)` et `orderBy('b')` sur des champs
///   différents (même instruction) : exige un **index composite**
///   (`indexes`) de la collection, champs d'égalité puis tris, dans cet ordre.
///
/// Limite assumée : analyse textuelle d'instructions à noms de collections et
/// de champs **littéraux**. Un nom non littéral est une violation (le contrôle
/// refuse de deviner), pas un passage.
List<String> checkIndexes({required Directory lib, required File indexesFile}) {
  final Map<String, Object?> config;
  try {
    config = jsonDecode(indexesFile.readAsStringSync()) as Map<String, Object?>;
  } on Object catch (error) {
    return ['${indexesFile.path} : illisible ($error)'];
  }
  final overrides = _list(config['fieldOverrides']);
  final composites = _list(config['indexes']);
  final violations = <String>[];

  final files =
      lib
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart') &&
                !f.path.endsWith('.config.dart') &&
                !f.path.endsWith('.steps.dart') &&
                !f.path.contains('/l10n/generated/'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    if (adapterFiles.any(file.path.endsWith)) continue;
    final raw = file.readAsStringSync();
    final source = _stripComments(raw);
    final firestoreFile = raw.contains('package:cloud_firestore/');
    for (final statement in source.split(';')) {
      // Les `where` / `orderBy` des listes Dart et de drift ne sont pas des
      // requêtes Firestore : seules comptent les instructions qui nomment une
      // collection, ou celles d'un fichier qui importe le SDK.
      if (!firestoreFile &&
          !statement.contains('collectionGroup(') &&
          !_collectionCall.hasMatch(statement)) {
        continue;
      }
      violations.addAll(
        checkStatement(
          statement,
          where: file.path,
          overrides: overrides,
          composites: composites,
        ),
      );
    }
  }
  return violations;
}

/// Le port `DocumentStore` et ses trois réalisations : ils **transmettent** un
/// nom de collection et un champ reçus en paramètre. Les appelants, eux, sont
/// contrôlés. Liste fermée, figée par `test/tool/check_indexes_test.dart`.
const adapterFiles = [
  'lib/shared/persistence/document_store.dart',
  'lib/shared/persistence/in_memory_document_store.dart',
  'lib/app/platform/firestore_document_store.dart',
];

final _groupCall = RegExp(r'collectionGroup\(\s*([^,)]*)');
final _literal = RegExp(r'''^['"]([^'"]+)['"]$''');
final _fieldArg = RegExp(r'''\bfield:\s*(['"])([^'"]+)\1''');
final _whereCall = RegExp(r'''\.where\(\s*(['"])([^'"]+)\1''');
final _orderByCall = RegExp(r'''\.orderBy\(\s*(['"])([^'"]+)\1''');
final _collectionCall = RegExp(r'''\.collection\(\s*(['"])([^'"/]+)\1''');
final _anyOrderBy = RegExp(r'\.orderBy\(');
final _anyWhere = RegExp(r'\.where\(');

/// Contrôle une instruction ; vide si elle ne demande aucun index ou si tous
/// ceux qu'elle demande sont déclarés.
List<String> checkStatement(
  String statement, {
  required String where,
  required List<Map<String, Object?>> overrides,
  required List<Map<String, Object?>> composites,
}) {
  final violations = <String>[];
  final groups = _groupCall.allMatches(statement).toList();
  final equality = [
    for (final m in _fieldArg.allMatches(statement)) m.group(2)!,
    for (final m in _whereCall.allMatches(statement)) m.group(2)!,
  ];
  final orders = [
    for (final m in _orderByCall.allMatches(statement)) m.group(2)!,
  ];
  final hasDynamicQuery =
      _anyWhere.allMatches(statement).length !=
          _whereCall.allMatches(statement).length ||
      _anyOrderBy.allMatches(statement).length != orders.length;

  String? collection;
  var scope = 'COLLECTION';
  for (final group in groups) {
    final match = _literal.firstMatch(group.group(1)!.trim());
    if (match == null) {
      violations.add(
        '$where : collectionGroup(${group.group(1)!.trim()}) : '
        'identifiant non littéral, index invérifiable',
      );
      continue;
    }
    collection = match.group(1);
    scope = 'COLLECTION_GROUP';
    for (final field in equality.toSet()) {
      if (orders.isNotEmpty) break; // requête composée : index composite
      if (!_hasGroupExemption(overrides, collection!, field)) {
        violations.add(
          "$where : collectionGroup('$collection') filtré sur '$field' : "
          'exemption COLLECTION_GROUP absente de firestore.indexes.json '
          '(fieldOverrides)',
        );
      }
    }
  }
  if (groups.isEmpty && collection == null) {
    final named = _collectionCall.allMatches(statement).toList();
    if (named.isNotEmpty) collection = named.last.group(2);
  }

  final composite =
      equality.isNotEmpty && orders.any((order) => !equality.contains(order));
  if (hasDynamicQuery) {
    violations.add(
      '$where : where/orderBy à champ non littéral, index invérifiable',
    );
  } else if (composite) {
    if (collection == null) {
      violations.add(
        '$where : requête composée sur une collection non littérale, '
        'index invérifiable',
      );
    } else if (!_hasComposite(
      composites,
      collection,
      scope,
      equality,
      orders,
    )) {
      violations.add(
        "$where : requête composée sur '$collection' "
        '(${equality.toSet().join(', ')} puis tri ${orders.join(', ')}) : '
        'index composite absent de firestore.indexes.json (indexes)',
      );
    }
  }
  return violations;
}

bool _hasGroupExemption(
  List<Map<String, Object?>> overrides,
  String collection,
  String field,
) => overrides.any(
  (o) =>
      o['collectionGroup'] == collection &&
      o['fieldPath'] == field &&
      _list(o['indexes']).any((i) => i['queryScope'] == 'COLLECTION_GROUP'),
);

bool _hasComposite(
  List<Map<String, Object?>> composites,
  String collection,
  String scope,
  List<String> equality,
  List<String> orders,
) {
  final eq = equality.toSet().difference(orders.toSet()).toList();
  for (final index in composites) {
    if (index['collectionGroup'] != collection ||
        index['queryScope'] != scope) {
      continue;
    }
    final fields = [
      for (final f in _list(index['fields'])) f['fieldPath']! as String,
    ];
    if (fields.length != eq.length + orders.length) continue;
    final head = fields.take(eq.length).toSet();
    final tail = fields.skip(eq.length).toList();
    if (head.length == eq.length &&
        head.containsAll(eq) &&
        _sameList(tail, orders)) {
      return true;
    }
  }
  return false;
}

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

List<Map<String, Object?>> _list(Object? raw) => [
  if (raw is List<Object?>)
    for (final item in raw)
      if (item is Map<String, Object?>) item,
];

/// Retire les commentaires `//` et `/* */` (les chaînes ne sont pas parsées :
/// un `//` dans une chaîne est rare dans le code d'accès aux données).
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');
