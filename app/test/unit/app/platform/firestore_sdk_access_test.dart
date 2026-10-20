import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// `FirestoreSdkAccess` est le seul code qui touche le SDK : on le joue contre
/// un faux `FirebaseFirestore` en mémoire (les règles de sécurité, elles, sont
/// testées contre l'émulateur par `scripts/rules_test/`).
void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSdkAccess access;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    access = FirestoreSdkAccess(firestore: () => firestore);
  });

  group('readDocument', () {
    test('returns the fields of an existing document', () async {
      await firestore.doc('clubs/c1').set({'name': 'Club un'});

      expect(await access.readDocument('clubs/c1'), {'name': 'Club un'});
    });

    test('returns null for a missing document', () async {
      expect(await access.readDocument('clubs/absent'), isNull);
    });
  });

  group('readDocumentFromServer (never the cache)', () {
    test('returns the fields, or null for a missing document', () async {
      await firestore.doc('clubs/c1').set({'name': 'Club un'});

      expect(await access.readDocumentFromServer('clubs/c1'), {
        'name': 'Club un',
      });
      expect(await access.readDocumentFromServer('clubs/absent'), isNull);
    });

    test('asks for the server source, and offline is an error, not the '
        'cache', () async {
      final paths = <String>[];
      final serving = FirestoreSdkAccess(
        firestore: () => firestore,
        readFromServer: (path) {
          paths.add(path);
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        },
      );

      await expectLater(
        serving.readDocumentFromServer('clubs/c1'),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
      expect(paths, ['clubs/c1']);
    });
  });

  group('peekDocument (local cache only)', () {
    test(
      'returns the fields of a document and null for a missing one',
      () async {
        await firestore.doc('clubs/c1').set({'name': 'Club un'});

        expect(await access.peekDocument('clubs/c1'), {'name': 'Club un'});
        expect(await access.peekDocument('clubs/absent'), isNull);
      },
    );

    test('a document the cache does not know (« unavailable ») is null, any '
        'other failure is raised', () async {
      var code = 'unavailable';
      final peeking = FirestoreSdkAccess(
        firestore: () => firestore,
        readFromCache: (path) =>
            throw FirebaseException(plugin: 'cloud_firestore', code: code),
      );

      expect(await peeking.peekDocument('clubs/c1'), isNull);

      code = 'permission-denied';
      await expectLater(
        peeking.peekDocument('clubs/c1'),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });
  });

  group('readCollection', () {
    test('returns each document with its full path and its fields', () async {
      await firestore.doc('clubs/c1/members/u1').set({'role': 'teacher'});
      await firestore.doc('clubs/c1/members/u2').set({'role': 'student'});
      await firestore.doc('clubs/c2/members/u3').set({'role': 'director'});

      final read = await access.readCollection('clubs/c1/members');

      expect(
        {for (final d in read) d.path: d.data},
        {
          'clubs/c1/members/u1': {'role': 'teacher'},
          'clubs/c1/members/u2': {'role': 'student'},
        },
      );
    });

    test('is empty for a collection with no document', () async {
      expect(await access.readCollection('clubs/c1/members'), isEmpty);
    });
  });

  group('readGroup', () {
    test('filters the collection group on the field, across clubs', () async {
      await firestore.doc('clubs/c1/members/u1').set({'uid': 'u1'});
      await firestore.doc('clubs/c2/members/u1').set({'uid': 'u1'});
      await firestore.doc('clubs/c1/members/u2').set({'uid': 'u2'});
      await firestore.doc('clubs/c1/groups/u1').set({'uid': 'u1'});

      final read = await access.readGroup('members', 'uid', 'u1');

      expect([for (final d in read) d.path]..sort(), [
        'clubs/c1/members/u1',
        'clubs/c2/members/u1',
      ]);
    });

    test('finds nothing for another value', () async {
      await firestore.doc('clubs/c1/members/u1').set({'uid': 'u1'});

      expect(await access.readGroup('members', 'uid', 'u9'), isEmpty);
    });
  });

  group('readQuery', () {
    test('equality keeps the documents of that collection only', () async {
      await firestore.doc('clubs/c1/memberships/a').set({'groupId': 'g1'});
      await firestore.doc('clubs/c1/memberships/b').set({'groupId': 'g2'});
      await firestore.doc('clubs/c2/memberships/c').set({'groupId': 'g1'});

      final read = await access.readQuery(
        'clubs/c1/memberships',
        'groupId',
        contains: false,
        value: 'g1',
      );

      expect([for (final d in read) d.path], ['clubs/c1/memberships/a']);
    });

    test('array-contains-any matches one of several values', () async {
      await firestore.doc('clubs/c1/students/s1').set({
        'groupIds': ['g1'],
      });
      await firestore.doc('clubs/c1/students/s2').set({
        'groupIds': ['g2', 'g3'],
      });
      await firestore.doc('clubs/c1/students/s3').set({'groupIds': <String>[]});

      final read = await access.readQuery(
        'clubs/c1/students',
        'groupIds',
        contains: true,
        value: ['g1', 'g3'],
      );

      expect([for (final d in read) d.path]..sort(), [
        'clubs/c1/students/s1',
        'clubs/c1/students/s2',
      ]);
    });
  });

  group('readQueryAll', () {
    test('every equality must hold, in that collection only', () async {
      await firestore.doc('clubs/c1/attempts/a').set({
        'groupId': 'g1',
        'sessionId': 'x1',
      });
      await firestore.doc('clubs/c1/attempts/b').set({
        'groupId': 'g1',
        'sessionId': 'x2',
      });
      await firestore.doc('clubs/c1/attempts/c').set({
        'groupId': 'g2',
        'sessionId': 'x1',
      });
      await firestore.doc('clubs/c2/attempts/d').set({
        'groupId': 'g1',
        'sessionId': 'x1',
      });

      final read = await access.readQueryAll('clubs/c1/attempts', {
        'groupId': 'g1',
        'sessionId': 'x1',
      });

      expect([for (final d in read) d.path], ['clubs/c1/attempts/a']);
    });
  });

  group('writeBatch', () {
    test('set replaces the document, update keeps the other fields', () async {
      await firestore.doc('a/set').set({'keep': 1, 'old': 1});
      await firestore.doc('a/upd').set({'keep': 1, 'old': 1});

      await access.writeBatch([
        (path: 'a/set', kind: RawWriteKind.set, data: {'new': 2}),
        (path: 'a/upd', kind: RawWriteKind.update, data: {'new': 2}),
      ]);

      expect((await firestore.doc('a/set').get()).data(), {'new': 2});
      expect((await firestore.doc('a/upd').get()).data(), {
        'keep': 1,
        'old': 1,
        'new': 2,
      });
    });

    test(
      'a merging set keeps the other fields and creates if absent',
      () async {
        await firestore.doc('a/m').set({
          'keep': 1,
          'ids': ['x'],
        });

        await access.writeBatch([
          (
            path: 'a/m',
            kind: RawWriteKind.setMerge,
            data: {'new': 2, 'ids': FieldValue.arrayUnion(<String>[])},
          ),
          (path: 'a/n', kind: RawWriteKind.setMerge, data: {'new': 3}),
        ]);

        expect((await firestore.doc('a/m').get()).data(), {
          'keep': 1,
          'ids': ['x'],
          'new': 2,
        });
        expect((await firestore.doc('a/n').get()).data(), {'new': 3});
      },
    );

    test('delete removes the document, and only that one', () async {
      await firestore.doc('a/gone').set({'x': 1});
      await firestore.doc('a/stays').set({'x': 1});

      await access.writeBatch([
        (path: 'a/gone', kind: RawWriteKind.delete, data: null),
      ]);

      expect((await firestore.doc('a/gone').get()).exists, isFalse);
      expect((await firestore.doc('a/stays').get()).exists, isTrue);
    });

    test('writes the fields as the SDK holds them (timestamps)', () async {
      final when = Timestamp.fromDate(DateTime.utc(2026, 10, 12, 9, 30));

      await access.writeBatch([
        (path: 'a/t', kind: RawWriteKind.set, data: {'at': when}),
      ]);

      expect(await access.readDocument('a/t'), {'at': when});
    });

    test('an empty batch writes nothing and does not fail', () async {
      await access.writeBatch(const []);

      expect((await firestore.collection('a').get()).docs, isEmpty);
    });
  });
}
