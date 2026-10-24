import 'package:billard_cfa/entities/invitation/data/store_invitation_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_failure.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixed_clock.dart';

void main() {
  late InMemoryDocumentStore store;
  late FixedClock clock;
  late StoreInvitationRepository repository;
  final code = InvitationCode.tryParse('ABCDEFGHJKMN')!;
  const user = UserId('u-new');

  Invitation invitation({
    Role role = Role.guardian,
    List<GroupId> groups = const [GroupId('g1')],
    List<StudentId> students = const [StudentId('s1')],
    Duration validity = const Duration(days: 7),
  }) => Invitation(
    code: code,
    clubId: const ClubId('c1'),
    role: role,
    createdBy: const UserId('u-dir'),
    createdAt: clock.now(),
    expiresAt: clock.now().add(validity),
    groupIds: groups,
    studentIds: students,
  );

  setUp(() {
    clock = FixedClock(DateTime(2026, 10, 12, 9, 30));
    store = InMemoryDocumentStore()..serverNow = clock.now;
    repository = StoreInvitationRepository(store, clock);
  });

  Future<void> accept({String name = 'Camille'}) =>
      repository.accept(code: code, user: user, displayName: name);

  Matcher refusedWith(InvitationFailureCode expected) =>
      throwsA(isA<InvitationFailure>().having((e) => e.code, 'code', expected));

  group('create, find, revoke', () {
    test('writes the fields the rules expect, with a server date', () async {
      await repository.create(invitation());

      expect(store.read('invitations/ABCDEFGHJKMN'), {
        'clubId': 'c1',
        'role': 'guardian',
        'groupIds': ['g1'],
        'studentIds': ['s1'],
        'createdBy': 'u-dir',
        'createdAt': clock.now(),
        'expiresAt': clock.now().add(const Duration(days: 7)),
        'used': false,
      });
    });

    test('finds the invitation it created', () async {
      final created = invitation();
      await repository.create(created);

      final found = await repository.find(code);

      expect(found, created);
    });

    test('an unknown code is null', () async {
      expect(await repository.find(code), isNull);
    });

    test('an unreadable document is null, never a crash', () async {
      store.seed('invitations/ABCDEFGHJKMN', {'role': 'wizard'});
      expect(await repository.find(code), isNull);
      store.seed('invitations/ABCDEFGHJKMN', {
        'clubId': 'c1',
        'role': 'teacher',
        'createdBy': 'u',
        'createdAt': DateTime(2026),
        'expiresAt': DateTime(2025),
      });
      expect(await repository.find(code), isNull);
    });

    test('a used invitation is read with who used it', () async {
      await repository.create(invitation());
      store.seed('invitations/ABCDEFGHJKMN', {
        ...store.read('invitations/ABCDEFGHJKMN')!,
        'used': true,
        'usedBy': 'u-x',
      });
      final found = (await repository.find(code))!;
      expect(found.used, isTrue);
      expect(found.usedBy, const UserId('u-x'));
    });

    test('revoking deletes the document, and is harmless twice', () async {
      await repository.create(invitation());

      await repository.revoke(code);
      await repository.revoke(code);

      expect(store.read('invitations/ABCDEFGHJKMN'), isNull);
    });
  });

  group('unusedIssuedBy', () {
    void put(
      String code, {
      String club = 'c1',
      String by = 'u-me',
      bool used = false,
    }) => store.seed('invitations/$code', {
      'clubId': club,
      'role': 'student',
      'groupIds': ['g1'],
      'studentIds': ['s1'],
      'createdBy': by,
      'createdAt': clock.now(),
      'expiresAt': clock.now().add(const Duration(days: 7)),
      'used': used,
    });

    test('the unused invitations this account created in the club, read at '
        'the server, by the two equalities the rules prove', () async {
      store = _ServerOnlyStore()..serverNow = clock.now;
      repository = StoreInvitationRepository(store, clock);
      put('AAAAAAAAAA');
      put('BBBBBBBBBB', used: true);
      put('CCCCCCCCCC', by: 'u-colleague');
      put('DDDDDDDDDD', club: 'c2');
      put('EEEEEEEEEE');
      store.seed('invitations/not-a-code', {
        'clubId': 'c1',
        'createdBy': 'u-me',
        'used': false,
      });

      final codes = await repository.unusedIssuedBy(
        const UserId('u-me'),
        const ClubId('c1'),
      );

      expect(codes.map((code) => code.value), ['AAAAAAAAAA', 'EEEEEEEEEE']);
      final filter = store.queryLog.single as AllEqual;
      expect(
        {for (final clause in filter.clauses) clause.field: clause.value},
        {'clubId': 'c1', 'createdBy': 'u-me'},
      );
    });

    test(
      'an unreachable server is a ServiceFailure, never an empty list',
      () async {
        store.failing = StoreFailureCode.unavailable;

        await expectLater(
          repository.unusedIssuedBy(const UserId('u-me'), const ClubId('c1')),
          throwsA(
            isA<ServiceFailure>().having(
              (f) => f.code,
              'code',
              ServiceFailureCode.unavailable,
            ),
          ),
        );
      },
    );
  });

  group('accept', () {
    test(
      'creates the member and consumes the invitation in ONE batch',
      () async {
        await repository.create(invitation());
        final commitsBefore = store.commits;

        await accept();

        expect(store.commits - commitsBefore, 1);
        expect(store.read('clubs/c1/members/u-new'), {
          'uid': 'u-new',
          'role': 'guardian',
          'groupIds': ['g1'],
          'studentIds': ['s1'],
          'displayName': 'Camille',
          'invitationCode': 'ABCDEFGHJKMN',
          'createdAt': clock.now(),
        });
        final used = store.read('invitations/ABCDEFGHJKMN')!;
        expect(used['used'], isTrue);
        expect(used['usedBy'], 'u-new');
        expect(used['usedAt'], clock.now());
      },
    );

    test(
      'the batch is all or nothing: a failure leaves both untouched',
      () async {
        await repository.create(invitation());
        // Le document de l'invitation disparaît entre la lecture et le lot.
        store.failing = null;
        final broken = _VanishingStore(store, 'invitations/ABCDEFGHJKMN');
        final racy = StoreInvitationRepository(broken, clock);

        await expectLater(
          racy.accept(code: code, user: user, displayName: 'Camille'),
          refusedWith(InvitationFailureCode.notFound),
        );
        expect(store.read('clubs/c1/members/u-new'), isNull);
      },
    );

    test('a trimmed name is stored', () async {
      await repository.create(invitation());
      await accept(name: '  Camille ');
      expect(store.read('clubs/c1/members/u-new')!['displayName'], 'Camille');
    });

    test(
      'refuses a blank or too long name before touching the server',
      () async {
        await repository.create(invitation());
        final reads = store.reads;
        await expectLater(
          accept(name: '   '),
          throwsA(
            isA<InvariantViolation>().having(
              (e) => e.code,
              'code',
              InvariantCode.nameRequired,
            ),
          ),
        );
        await expectLater(
          accept(name: 'é' * (maxDisplayNameLength + 1)),
          throwsA(
            isA<InvariantViolation>().having(
              (e) => e.code,
              'code',
              InvariantCode.nameTooLong,
            ),
          ),
        );
        await accept(name: 'é' * maxDisplayNameLength);
        expect(reads, store.reads - 1, reason: 'les deux refus n’ont rien lu');
      },
    );

    test('an unknown code is not found', () async {
      await expectLater(accept(), refusedWith(InvitationFailureCode.notFound));
      expect(store.read('clubs/c1/members/u-new'), isNull);
    });

    test('an expired invitation is refused with its own reason', () async {
      await repository.create(invitation(validity: const Duration(hours: 48)));
      clock.advance(const Duration(hours: 48));

      await expectLater(accept(), refusedWith(InvitationFailureCode.expired));
      expect(store.read('clubs/c1/members/u-new'), isNull);
      expect(store.read('invitations/ABCDEFGHJKMN')!['used'], isFalse);
    });

    test('is still valid one second before it expires', () async {
      await repository.create(invitation(validity: const Duration(hours: 48)));
      clock.advance(const Duration(hours: 48) - const Duration(seconds: 1));

      await accept();

      expect(store.read('clubs/c1/members/u-new'), isNotNull);
    });

    test('a used invitation is refused, and cannot be used twice', () async {
      await repository.create(invitation());
      await accept();

      await expectLater(
        repository.accept(
          code: code,
          user: const UserId('u-other'),
          displayName: 'Autre',
        ),
        refusedWith(InvitationFailureCode.used),
      );
      expect(store.read('clubs/c1/members/u-other'), isNull);
    });

    test('a refusal of the server rules is reported as refused', () async {
      await repository.create(invitation());
      store.failing = null;
      final denying = _FailingCommitStore(
        store,
        StoreFailureCode.permissionDenied,
      );

      await expectLater(
        StoreInvitationRepository(
          denying,
          clock,
        ).accept(code: code, user: user, displayName: 'C'),
        refusedWith(InvitationFailureCode.refused),
      );
    });

    test('an unreachable service is a ServiceFailure, not a refusal', () async {
      await repository.create(invitation());
      for (final (failure, expected) in [
        (StoreFailureCode.unavailable, ServiceFailureCode.unavailable),
        (StoreFailureCode.other, ServiceFailureCode.other),
      ]) {
        await expectLater(
          StoreInvitationRepository(
            _FailingCommitStore(store, failure),
            clock,
          ).accept(code: code, user: user, displayName: 'C'),
          throwsA(
            isA<ServiceFailure>().having((e) => e.code, 'code', expected),
          ),
        );
      }
    });

    test('InvitationFailure prints its code', () {
      expect(
        const InvitationFailure(InvitationFailureCode.expired).toString(),
        'InvitationFailure(expired)',
      );
    });
  });
}

/// Un stock dont un document disparaît après sa première lecture : la
/// course « l'invitation est révoquée pendant que l'invité valide ».
class _VanishingStore implements DocumentStore {
  _VanishingStore(this._inner, this._path);

  final InMemoryDocumentStore _inner;
  final String _path;

  @override
  Future<StoredDocument?> peek(String path) => _inner.peek(path);

  @override
  Future<StoredDocument?> getFromServer(String path) =>
      _inner.getFromServer(path);

  @override
  Future<StoredDocument?> get(String path) async {
    final document = await _inner.get(path);
    if (path == _path) _inner.remove(path);
    return document;
  }

  @override
  Future<List<StoredDocument>> list(String collection) =>
      _inner.list(collection);

  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) =>
      _inner.query(collection, filter);

  /// Sans cache dans ce double : la lecture au serveur est [query].
  @override
  Future<List<StoredDocument>> queryFromServer(
    String collection,
    QueryFilter filter,
  ) => query(collection, filter);

  /// Sans cache dans ce double : la lecture au serveur est [collectionGroup].
  @override
  Future<List<StoredDocument>> collectionGroupFromServer(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => collectionGroup(collectionId, field: field, equalTo: equalTo);

  @override
  Future<List<StoredDocument>> collectionGroup(
    String id, {
    required String field,
    required Object? equalTo,
  }) => _inner.collectionGroup(id, field: field, equalTo: equalTo);

  @override
  Future<bool> createIfAbsent(String path, Fields fields) =>
      _inner.createIfAbsent(path, fields);

  @override
  Future<void> commit(List<WriteOp> operations) => _inner.commit(operations);

  @override
  Stream<DocumentUpdate> watchDocument(String path) =>
      _inner.watchDocument(path);

  @override
  Stream<CollectionUpdate> watchCollection(String collection) =>
      _inner.watchCollection(collection);

  @override
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) =>
      _inner.watchQuery(collection, filter);
}

/// Un stock dont les lots échouent avec [code] (lectures normales).
class _FailingCommitStore implements DocumentStore {
  _FailingCommitStore(this._inner, this.code);

  final InMemoryDocumentStore _inner;
  final StoreFailureCode code;

  @override
  Future<StoredDocument?> get(String path) => _inner.get(path);

  @override
  Future<StoredDocument?> getFromServer(String path) =>
      _inner.getFromServer(path);

  @override
  Future<StoredDocument?> peek(String path) => _inner.peek(path);

  @override
  Future<List<StoredDocument>> list(String collection) =>
      _inner.list(collection);

  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) =>
      _inner.query(collection, filter);

  /// Sans cache dans ce double : la lecture au serveur est [query].
  @override
  Future<List<StoredDocument>> queryFromServer(
    String collection,
    QueryFilter filter,
  ) => query(collection, filter);

  /// Sans cache dans ce double : la lecture au serveur est [collectionGroup].
  @override
  Future<List<StoredDocument>> collectionGroupFromServer(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => collectionGroup(collectionId, field: field, equalTo: equalTo);

  @override
  Future<List<StoredDocument>> collectionGroup(
    String id, {
    required String field,
    required Object? equalTo,
  }) => _inner.collectionGroup(id, field: field, equalTo: equalTo);

  @override
  Future<bool> createIfAbsent(String path, Fields fields) =>
      _inner.createIfAbsent(path, fields);

  @override
  Future<void> commit(List<WriteOp> operations) =>
      throw StoreFailure(code, 'test');

  @override
  Stream<DocumentUpdate> watchDocument(String path) =>
      _inner.watchDocument(path);

  @override
  Stream<CollectionUpdate> watchCollection(String collection) =>
      _inner.watchCollection(collection);

  @override
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) =>
      _inner.watchQuery(collection, filter);
}

/// Un stock dont le cache ne répond jamais : seule la lecture au serveur
/// aboutit (la requête ordinaire échoue).
class _ServerOnlyStore extends InMemoryDocumentStore {
  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) =>
      throw const StoreFailure(StoreFailureCode.other, 'lecture du cache');
}
