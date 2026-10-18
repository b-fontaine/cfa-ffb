import 'dart:async';

import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/settings/data/settings_document.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_rig.dart';

const _nice = ClubMembership(
  clubId: ClubId('nice'),
  clubName: 'Club Nice',
  role: Role.director,
);
const _lyon = ClubMembership(
  clubId: ClubId('lyon'),
  clubName: 'Club Lyon',
  role: Role.teacher,
);

ClubSettings _settings({required int passes, int alert = 3}) => ClubSettings(
  passesRequired: passes,
  alertThreshold: alert,
  recallStaleSessions: 4,
  groupFailureSharePercent: 50,
  backupReminderDays: 30,
);

/// Réglages dont la lecture de chaque club attend qu'on la libère : permet de
/// finir deux chargements dans l'ordre inverse de leur début.
class _GatedSettings implements SettingsRepository {
  _GatedSettings(this._scope, this._inner);

  final SessionScope _scope;
  final SettingsRepository _inner;
  final Map<ClubId, Completer<void>> _gates = {};

  /// Clubs dont la lecture, une fois libérée, échoue (réseau, refus).
  final Set<ClubId> failing = {};

  Completer<void> _gate(ClubId club) => _gates.putIfAbsent(club, Completer.new);

  void release(ClubId club) => _gate(club).complete();

  @override
  Future<ClubSettings> load() {
    // La lecture part tout de suite, avec le club actif À CE MOMENT (le chemin
    // est évalué au début de l'appel) ; seule sa fin est retenue.
    final club = _scope.clubId!;
    final read = _inner.load();
    return _gate(club).future.then((_) {
      if (failing.contains(club)) {
        throw const ServiceFailure(ServiceFailureCode.other, 'late');
      }
      return read;
    });
  }

  @override
  Future<void> save(ClubSettings settings) => _inner.save(settings);

  @override
  Future<void> reset() => _inner.reset();
}

/// Les règles courantes suivent le club actif (ADR 0024, A5 et A11) : les
/// réglages du **club** (un document par club) sont rechargés à l'activation
/// d'un club et à la bascule ; ils ne sont plus lus avant l'ouverture de
/// session (le club est absent, l'accès refusé).
void main() {
  late InMemoryDocumentStore documents;
  late AuthRig rig;

  setUp(() {
    documents = InMemoryDocumentStore()
      ..seed(
        'clubs/nice/settings/main',
        SettingsDocument.encode(_settings(passes: 3)),
      )
      ..seed(
        'clubs/lyon/settings/main',
        SettingsDocument.encode(_settings(passes: 7, alert: 4)),
      );
    rig = AuthRig(
      settings: (scope) =>
          FirestoreSettingsRepository(ClubStore(documents, scope)),
    );
    addTearDown(rig.cubit.close);
    final coach = rig.auth.seed(email: 'coach@example.org', password: 'pw');
    rig.memberships
      ..grant(coach.id, _nice)
      ..grant(coach.id, _lyon);
  });

  Future<void> signedInAndChosen(ClubMembership club) async {
    rig.auth.restoreSession('coach@example.org');
    await rig.cubit.start();
    await pumpEventQueue();
    expect(await rig.cubit.chooseClub(club), isTrue);
  }

  test('loads the settings of the club on its activation', () async {
    expect(rig.rules.current.passesRequired, 5);

    await signedInAndChosen(_nice);

    expect(rig.rules.current.passesRequired, 3);
    expect(rig.rules.current.alertThreshold, 3);
  });

  test('loads the settings of the other club on a switch', () async {
    await signedInAndChosen(_nice);

    expect(await rig.cubit.chooseClub(_lyon), isTrue);

    expect(rig.rules.current.passesRequired, 7);
    expect(rig.rules.current.alertThreshold, 4);
  });

  test('a club without settings document uses the defaults, not the rules '
      'of the previous club', () async {
    documents.remove('clubs/lyon/settings/main');
    await signedInAndChosen(_nice);
    expect(rig.rules.current.passesRequired, 3);

    expect(await rig.cubit.chooseClub(_lyon), isTrue);

    expect(rig.rules.current.passesRequired, 5);
  });

  test('settings the server refuses to read leave the defaults, and the '
      'club still opens', () async {
    documents.failing = StoreFailureCode.permissionDenied;

    await signedInAndChosen(_nice);

    expect(rig.rules.current.passesRequired, 5);
    expect(rig.scope.clubId, const ClubId('nice'));
  });

  test('signing out forgets the rules of the club', () async {
    await signedInAndChosen(_nice);
    expect(rig.rules.current.passesRequired, 3);

    await rig.cubit.signOut();

    expect(rig.rules.current.passesRequired, 5);
  });

  test(
    'the rules that are not club settings stay: the base survives a switch',
    () async {
      rig.rules.base = rig.rules.base.copyWith(persistentAlertThreshold: 9);
      rig.rules.current = rig.rules.base;
      await signedInAndChosen(_nice);
      expect(rig.rules.current.persistentAlertThreshold, 9);
      expect(rig.rules.current.passesRequired, 3);

      await rig.cubit.chooseClub(_lyon);
      expect(rig.rules.current.persistentAlertThreshold, 9);
      expect(rig.rules.current.passesRequired, 7);

      await rig.cubit.signOut();
      expect(rig.rules.current, rig.rules.base);
    },
  );

  test('the device preferences are not touched by a club switch', () async {
    await signedInAndChosen(_nice);
    final before = Map.of(rig.store.entries);

    await rig.cubit.chooseClub(_lyon);

    // Seul le club retenu change (préférence d'appareil de la décision 22) :
    // aucune clé n'est ajoutée ni lue des réglages du club.
    expect(rig.store.entries.keys, before.keys);
  });

  group('a load that ends late never overrides a newer state', () {
    late _GatedSettings gated;

    setUp(() {
      documents = InMemoryDocumentStore()
        ..seed(
          'clubs/nice/settings/main',
          SettingsDocument.encode(_settings(passes: 3)),
        )
        ..seed(
          'clubs/lyon/settings/main',
          SettingsDocument.encode(_settings(passes: 7, alert: 4)),
        );
      rig = AuthRig(
        settings: (scope) => gated = _GatedSettings(
          scope,
          FirestoreSettingsRepository(ClubStore(documents, scope)),
        ),
      );
      addTearDown(rig.cubit.close);
      final coach = rig.auth.seed(email: 'coach@example.org', password: 'pw');
      rig.memberships
        ..grant(coach.id, _nice)
        ..grant(coach.id, _lyon);
    });

    test('a switch while the first club loads: the rules are those of the '
        'last club even if the first load ends last', () async {
      rig.auth.restoreSession('coach@example.org');
      await rig.cubit.start();
      await pumpEventQueue();
      final first = rig.cubit.chooseClub(_nice);
      await pumpEventQueue();
      final second = rig.cubit.chooseClub(_lyon);
      await pumpEventQueue();

      gated.release(const ClubId('lyon'));
      await second;
      gated.release(const ClubId('nice'));
      await first;
      await pumpEventQueue();

      expect(rig.scope.clubId, const ClubId('lyon'));
      expect(rig.rules.current.passesRequired, 7);
    });

    test('signing out while the club loads: the late load does not bring '
        'its rules back', () async {
      rig.auth.restoreSession('coach@example.org');
      await rig.cubit.start();
      await pumpEventQueue();
      final choosing = rig.cubit.chooseClub(_nice);
      await pumpEventQueue();

      await rig.cubit.signOut();
      gated.release(const ClubId('nice'));
      await choosing;
      await pumpEventQueue();

      expect(rig.rules.current.passesRequired, 5);
    });

    test('a first load that FAILS late, after a switch: the rules of the '
        'last club stay', () async {
      rig.auth.restoreSession('coach@example.org');
      await rig.cubit.start();
      await pumpEventQueue();
      final first = rig.cubit.chooseClub(_nice);
      await pumpEventQueue();
      final second = rig.cubit.chooseClub(_lyon);
      await pumpEventQueue();
      gated.failing.add(const ClubId('nice'));

      gated.release(const ClubId('lyon'));
      await second;
      expect(rig.rules.current.passesRequired, 7);
      gated.release(const ClubId('nice'));
      await first;
      await pumpEventQueue();

      expect(rig.scope.clubId, const ClubId('lyon'));
      expect(rig.rules.current.passesRequired, 7);
      expect(rig.rules.current.alertThreshold, 4);
    });

    test('a load that FAILS late, after signing out: the late failure '
        'does not touch the rules', () async {
      rig.auth.restoreSession('coach@example.org');
      await rig.cubit.start();
      await pumpEventQueue();
      final choosing = rig.cubit.chooseClub(_nice);
      await pumpEventQueue();
      gated.failing.add(const ClubId('nice'));
      // Règles posées « à la main » : seul un écrasement tardif les perdrait.
      final marker = rig.rules.base.copyWith(persistentAlertThreshold: 9);

      await rig.cubit.signOut();
      rig.rules.current = marker;
      gated.release(const ClubId('nice'));
      await choosing;
      await pumpEventQueue();

      expect(rig.rules.current, marker);
    });
  });
}
