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
