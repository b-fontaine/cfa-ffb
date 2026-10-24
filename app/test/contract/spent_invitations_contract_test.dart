import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/invitation/data/club_spent_invitations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixed_clock.dart';

/// Les invitations utilisées ou échues d'un club (FB8 partie B, B3), sur le
/// stock en mémoire et sur le faux Firestore : même contrat. Les règles
/// réelles (liste bornée au club et au rôle) sont jouées par
/// `scripts/rules_test/invitations.test.mjs`.
void main() {
  _contract('stock en mémoire', InMemoryDocumentStore.new);
  _contract('Firestore (fake_cloud_firestore)', () {
    final firestore = FakeFirebaseFirestore();
    return FirestoreDocumentStore(
      access: FirestoreSdkAccess(firestore: () => firestore),
    );
  });
}

final _now = DateTime.utc(2026, 10, 12, 10);

/// Une invitation telle que l'application l'écrit (chemin composé à la main,
/// comme dans `firestore.rules`).
SetOp _invitation(
  String code, {
  required String role,
  String club = 'c1',
  bool used = false,
  DateTime? expiresAt,
}) => SetOp('invitations/$code', {
  'clubId': club,
  'role': role,
  'groupIds': <String>[],
  'studentIds': <String>[],
  'createdBy': 'u-author',
  'createdAt': _now.subtract(const Duration(days: 3)),
  'expiresAt': expiresAt ?? _now.add(const Duration(hours: 40)),
  'used': used,
  if (used) 'usedBy': 'u-used',
});

void _contract(String name, DocumentStore Function() open) {
  group('ClubSpentInvitations ($name)', () {
    late DocumentStore documents;
    late SessionScope scope;
    late ClubSpentInvitations spent;
    final yesterday = _now.subtract(const Duration(days: 1));

    setUp(() async {
      documents = open();
      scope = SessionScope()..signIn(const UserId('u-dir'));
      spent = ClubSpentInvitations(
        ClubStore(documents, scope),
        FixedClock(_now),
      );
      await documents.commit([
        _invitation('VALIDTEACH', role: 'teacher'),
        _invitation('USEDSTUDNT', role: 'student', used: true),
        _invitation('OLDGUARDAA', role: 'guardian', expiresAt: yesterday),
        _invitation('NOWTEACHAA', role: 'teacher', expiresAt: _now),
        _invitation('OLDDIRECTA', role: 'director', expiresAt: yesterday),
        _invitation('USEDDIRECT', role: 'director', used: true),
        _invitation('OTHERCLUBA', role: 'teacher', club: 'c2', used: true),
      ]);
    });

    Future<List<String>> codes() async =>
        [for (final code in await spent.codes()) code.value]..sort();

    test('the administrator gets the used and expired invitations of the '
        'active club, of every role, and nothing else', () async {
      scope.activate(const ClubId('c1'), Role.admin);

      expect(await codes(), [
        'NOWTEACHAA',
        'OLDDIRECTA',
        'OLDGUARDAA',
        'USEDDIRECT',
        'USEDSTUDNT',
      ]);
    });

    test('the director gets only the roles he invites: never a director '
        'invitation', () async {
      scope.activate(const ClubId('c1'), Role.director);

      expect(await codes(), ['NOWTEACHAA', 'OLDGUARDAA', 'USEDSTUDNT']);
    });

    test('an invitation of another club is never listed', () async {
      scope.activate(const ClubId('c2'), Role.director);

      expect(await codes(), ['OTHERCLUBA']);
    });

    test('an invitation whose use and expiry cannot be read is left '
        'alone, never fatal', () async {
      await documents.commit([
        const SetOp('invitations/BROKENAAAA', {
          'clubId': 'c1',
          'role': 'teacher',
          'expiresAt': 'hier',
        }),
      ]);
      scope.activate(const ClubId('c1'), Role.admin);

      expect(await codes(), isNot(contains('BROKENAAAA')));
    });

    test('without an active club, nothing is read', () async {
      await expectLater(
        spent.codes(),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
    });

    test(
      'the lot deletes exactly the given invitations, one write each',
      () async {
        scope.activate(const ClubId('c1'), Role.director);
        final listed = await spent.codes();

        final lot = spent.remove(listed);
        await lot.apply();

        expect(lot.writes, 3);
        for (final code in ['NOWTEACHAA', 'OLDGUARDAA', 'USEDSTUDNT']) {
          expect(
            await documents.get('invitations/$code'),
            isNull,
            reason: code,
          );
        }
        for (final code in ['VALIDTEACH', 'OLDDIRECTA', 'OTHERCLUBA']) {
          expect(
            await documents.get('invitations/$code'),
            isNotNull,
            reason: code,
          );
        }
        scope.activate(const ClubId('c1'), Role.director);
        expect(await codes(), isEmpty);
      },
    );
  });
}
