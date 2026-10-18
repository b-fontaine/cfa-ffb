import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/indexes/index_rules.dart';

/// Un dossier `lib/` temporaire contenant [files] (chemin relatif -> source) et
/// un `firestore.indexes.json` de contenu [indexes].
({Directory lib, File indexes}) _fixture(
  Map<String, String> files,
  Map<String, Object?> indexes,
) {
  final root = Directory.systemTemp.createTempSync('check_indexes_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final entry in files.entries) {
    File('${root.path}/lib/${entry.key}')
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  final file = File('${root.path}/firestore.indexes.json')
    ..writeAsStringSync(jsonEncode(indexes));
  return (lib: Directory('${root.path}/lib'), indexes: file);
}

const _groupQuery = '''
Future<void> f(DocumentStore store) async {
  await store.collectionGroup('members', field: 'uid', equalTo: 'u');
}
''';

const _composedQuery = '''
Future<void> f(FirebaseFirestore db) async {
  await db.collection('sessions').where('groupId', isEqualTo: 'g').orderBy('day').get();
}
''';

const Map<String, Object?> _exemption = {
  'collectionGroup': 'members',
  'fieldPath': 'uid',
  'indexes': [
    {'order': 'ASCENDING', 'queryScope': 'COLLECTION'},
    {'order': 'ASCENDING', 'queryScope': 'COLLECTION_GROUP'},
  ],
};

const Map<String, Object?> _composite = {
  'collectionGroup': 'sessions',
  'queryScope': 'COLLECTION',
  'fields': [
    {'fieldPath': 'groupId', 'order': 'ASCENDING'},
    {'fieldPath': 'day', 'order': 'ASCENDING'},
  ],
};

void main() {
  group('the repository itself', () {
    final real = File('../firestore.indexes.json');

    test('declares every index its queries need', () {
      expect(checkIndexes(lib: Directory('lib'), indexesFile: real), isEmpty);
    });

    test('mutation: without the members.uid exemption the check fails', () {
      final config =
          jsonDecode(real.readAsStringSync()) as Map<String, Object?>;
      config['fieldOverrides'] = <Object?>[];
      final copy = File(
        '${Directory.systemTemp.createTempSync('mutant_').path}/i.json',
      )..writeAsStringSync(jsonEncode(config));
      addTearDown(() => copy.parent.deleteSync(recursive: true));

      final violations = checkIndexes(lib: Directory('lib'), indexesFile: copy);

      expect(violations, hasLength(1));
      expect(violations.single, contains('store_memberships_source.dart'));
      expect(violations.single, contains("'members'"));
    });

    test('only the document store and its adapters are exempt', () {
      for (final path in adapterFiles) {
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(path, contains('document_store.dart'));
      }
      expect(adapterFiles, hasLength(3));
    });
  });

  group('collection group queries', () {
    test('need their COLLECTION_GROUP exemption', () {
      final fx = _fixture(
        {'a.dart': _groupQuery},
        {'indexes': [], 'fieldOverrides': []},
      );

      expect(checkIndexes(lib: fx.lib, indexesFile: fx.indexes), hasLength(1));
    });

    test('pass with the exemption', () {
      final fx = _fixture(
        {'a.dart': _groupQuery},
        {
          'fieldOverrides': [_exemption],
        },
      );

      expect(checkIndexes(lib: fx.lib, indexesFile: fx.indexes), isEmpty);
    });

    test('a COLLECTION-only exemption is not enough', () {
      final fx = _fixture(
        {'a.dart': _groupQuery},
        {
          'fieldOverrides': [
            {
              'collectionGroup': 'members',
              'fieldPath': 'uid',
              'indexes': [
                {'order': 'ASCENDING', 'queryScope': 'COLLECTION'},
              ],
            },
          ],
        },
      );

      expect(checkIndexes(lib: fx.lib, indexesFile: fx.indexes), hasLength(1));
    });

    test('the SDK form is checked too', () {
      final fx = _fixture(
        {
          'a.dart':
              "void f(db) { db.collectionGroup('groups') "
              ".where('teacherUid', isEqualTo: 'u'); }",
        },
        {
          'fieldOverrides': [_exemption],
        },
      );

      final violations = checkIndexes(lib: fx.lib, indexesFile: fx.indexes);

      expect(violations.single, contains("'groups'"));
      expect(violations.single, contains("'teacherUid'"));
    });

    test('a non literal collection is refused, never guessed', () {
      final fx = _fixture(
        {
          'a.dart':
              'void f(DocumentStore s, String c) '
              '{ s.collectionGroup(c, field: "uid", equalTo: 1); }',
        },
        {
          'fieldOverrides': [_exemption],
        },
      );

      expect(
        checkIndexes(lib: fx.lib, indexesFile: fx.indexes).single,
        contains('non littéral'),
      );
    });
  });

  group('composed queries (where + orderBy on different fields)', () {
    test('need a composite index', () {
      final fx = _fixture({'a.dart': _composedQuery}, {'indexes': []});

      final violations = checkIndexes(lib: fx.lib, indexesFile: fx.indexes);

      expect(violations.single, contains("'sessions'"));
      expect(violations.single, contains('index composite'));
    });

    test('pass with the composite index', () {
      final fx = _fixture(
        {'a.dart': _composedQuery},
        {
          'indexes': [_composite],
        },
      );

      expect(checkIndexes(lib: fx.lib, indexesFile: fx.indexes), isEmpty);
    });

    test('mutation: the composite index removed makes it fail again', () {
      final withIndex = _fixture(
        {'a.dart': _composedQuery},
        {
          'indexes': [_composite],
        },
      );
      expect(
        checkIndexes(lib: withIndex.lib, indexesFile: withIndex.indexes),
        isEmpty,
      );
      withIndex.indexes.writeAsStringSync(jsonEncode({'indexes': <Object?>[]}));

      expect(
        checkIndexes(lib: withIndex.lib, indexesFile: withIndex.indexes),
        hasLength(1),
      );
    });

    test('the fields must be in query order', () {
      final fx = _fixture(
        {'a.dart': _composedQuery},
        {
          'indexes': [
            {
              ..._composite,
              'fields': [
                {'fieldPath': 'day', 'order': 'ASCENDING'},
                {'fieldPath': 'groupId', 'order': 'ASCENDING'},
              ],
            },
          ],
        },
      );

      expect(checkIndexes(lib: fx.lib, indexesFile: fx.indexes), hasLength(1));
    });

    test('a where and an orderBy on the same field need none', () {
      final fx = _fixture(
        {
          'a.dart':
              "void f(db) { db.collection('s') "
              ".where('day', isGreaterThan: 1).orderBy('day'); }",
        },
        {'indexes': []},
      );

      expect(checkIndexes(lib: fx.lib, indexesFile: fx.indexes), isEmpty);
    });
  });

  test('where and orderBy on Dart lists are not Firestore queries', () {
    final fx = _fixture(
      {'a.dart': 'void f(List<int> l) { l.where((x) => x > 1).toList(); }'},
      {'indexes': []},
    );

    expect(checkIndexes(lib: fx.lib, indexesFile: fx.indexes), isEmpty);
  });

  test('an unreadable index file is a violation', () {
    final fx = _fixture({'a.dart': ''}, {});
    fx.indexes.writeAsStringSync('{');

    expect(
      checkIndexes(lib: fx.lib, indexesFile: fx.indexes).single,
      contains('illisible'),
    );
  });
}
