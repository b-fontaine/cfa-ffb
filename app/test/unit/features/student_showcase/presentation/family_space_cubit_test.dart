import 'dart:async';

import 'package:billard_cfa/features/student_showcase/domain/check_family_access.dart';
import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/watch_family_space.dart';
import 'package:billard_cfa/features/student_showcase/presentation/bloc/family_space_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Get extends Mock implements GetFamilySpace;

class _Watch extends Mock implements WatchFamilySpace;

class _Access extends Mock implements CheckFamilyAccess;

FamilyChild _child(String id, String name) => FamilyChild(
  id: StudentId(id),
  firstName: name,
  showcase: StudentShowcase(
    firstName: name,
    rows: const [],
    current: null,
    validatedCount: 0,
    finishedTechniques: 0,
    techniqueCount: 0,
    toStart: true,
    passesRequired: 5,
  ),
);

FamilySpace _space(
  List<FamilyChild> children, [
  List<FamilySession> next = const [],
]) => FamilySpace(children: children, upcoming: next);

const _denied = ServiceFailure(ServiceFailureCode.denied);
const _unavailable = ServiceFailure(ServiceFailureCode.unavailable);

void main() {
  late _Get get;
  late _Watch watch;
  late _Access access;
  late StreamController<void> changes;
  late FamilySpaceCubit cubit;
  final lea = _child('s1', 'Léa');
  final tom = _child('s2', 'Tom');

  Future<void> settle() => pumpEventQueue(times: 50);

  setUp(() {
    get = _Get();
    watch = _Watch();
    access = _Access();
    changes = StreamController<void>.broadcast();
    when(() => watch()).thenAnswer((_) => changes.stream);
    when(() => access())
        .thenAnswer((_) async => const AccessGranted({StudentId('s1')}));
    cubit = FamilySpaceCubit(get, watch, access);
  });

  tearDown(() async {
    await cubit.close();
    await changes.close();
  });

  void answer(Result<FamilySpace> result) =>
      when(() => get(linked: any(named: 'linked')))
          .thenAnswer((_) async => result);

  test('an unexpected error becomes a failed state, never an escape', () async {
    when(() => access()).thenThrow(StateError('boom'));

    await cubit.load();

    expect(cubit.state.status, FamilyStatus.failed);
    expect(cubit.state.failure, const ServiceFailure(ServiceFailureCode.other));
  });

  test(
    'an unexpected error while reading the space is a failed state',
    () async {
      when(() => get(linked: any(named: 'linked')))
          .thenThrow(StateError('boom'));

      await cubit.load();

      expect(cubit.state.status, FamilyStatus.failed);
      expect(
        cubit.state.failure,
        const ServiceFailure(ServiceFailureCode.other),
      );
    },
  );

  test('a live reload that fails unexpectedly is shown, not thrown', () async {
    answer(Ok(_space([lea])));
    await cubit.load();
    when(() => get(linked: any(named: 'linked'))).thenThrow(StateError('boom'));

    changes.add(null);
    await settle();

    expect(cubit.state.status, FamilyStatus.failed);
  });

  test('loads the space and shows the first child', () async {
    answer(Ok(_space([lea, tom])));

    await cubit.load();

    expect(cubit.state.status, FamilyStatus.ready);
    expect(cubit.state.selected, lea.id);
    expect(cubit.state.stale, isFalse);
  });

  test('a child can be selected; an unknown one is ignored', () async {
    answer(Ok(_space([lea, tom])));
    await cubit.load();

    cubit.select(tom.id);
    expect(cubit.state.selected, tom.id);

    cubit.select(const StudentId('s9'));
    expect(cubit.state.selected, tom.id);
  });

  test('selecting before anything is loaded does nothing', () {
    cubit.select(lea.id);

    expect(cubit.state.selected, isNull);
  });

  test('the selection survives a reload, falls back if unlinked', () async {
    answer(Ok(_space([lea, tom])));
    await cubit.load();
    cubit.select(tom.id);

    changes.add(null);
    await settle();
    expect(cubit.state.selected, tom.id);

    answer(Ok(_space([lea])));
    changes.add(null);
    await settle();
    expect(cubit.state.selected, lea.id);
  });

  test(
    'a change on the server reloads in place, without a loading state',
    () async {
      answer(Ok(_space([lea])));
      final states = <FamilyStatus>[];
      cubit.stream.listen((state) => states.add(state.status));
      await cubit.load();

      answer(
        Ok(
          _space(
            [lea],
            [
              FamilySession(
                id: 'x',
                title: 'Séance',
                date: DateTime(2026, 10, 14),
                audience: Audience.children,
              ),
            ],
          ),
        ),
      );
      changes.add(null);
      await settle();

      expect(states, everyElement(FamilyStatus.ready));
      expect(cubit.state.space!.upcoming, hasLength(1));
    },
  );

  test('opens one subscription only, however often it loads', () async {
    answer(Ok(_space([lea])));

    await cubit.load();
    await cubit.load();

    verify(() => watch()).called(1);
  });

  test('a refusal while the link still exists is denied', () async {
    answer(const Err(_denied));

    await cubit.load();

    expect(cubit.state.status, FamilyStatus.denied);
    expect(cubit.state.space, isNull);
  });

  test(
    'a refusal when the link is gone is revoked: no data, subscription closed',
    () async {
      answer(Ok(_space([lea])));
      await cubit.load();
      expect(changes.hasListener, isTrue);

      when(() => access()).thenAnswer((_) async => const AccessRevoked());
      answer(const Err(_denied));
      changes.addError(_denied);
      await settle();

      expect(cubit.state.status, FamilyStatus.revoked);
      expect(cubit.state.space, isNull);
      expect(changes.hasListener, isFalse);
    },
  );

  test(
    'a link that is gone is revoked without reading the data: open listeners '
    'may still answer those reads, the link is the reliable signal',
    () async {
      answer(Ok(_space([lea])));
      await cubit.load();

      when(() => access()).thenAnswer((_) async => const AccessRevoked());
      clearInteractions(get);
      changes.addError(_denied);
      await settle();

      expect(cubit.state.status, FamilyStatus.revoked);
      verifyNever(() => get(linked: any(named: 'linked')));
      expect(changes.hasListener, isFalse);
    },
  );

  test('an access revoked at the first load shows no data', () async {
    when(() => access()).thenAnswer((_) async => const AccessRevoked());

    await cubit.load();

    expect(cubit.state.status, FamilyStatus.revoked);
    expect(cubit.state.space, isNull);
  });

  test(
    'only the children the link still lists are read: losing one of two keeps '
    'the other on screen, neither denied nor revoked',
    () async {
      when(() => access()).thenAnswer(
        (_) async => const AccessGranted({StudentId('s1'), StudentId('s2')}),
      );
      answer(Ok(_space([lea, tom])));
      await cubit.load();
      expect(cubit.state.space!.children, [lea, tom]);

      when(() => access())
          .thenAnswer((_) async => const AccessGranted({StudentId('s1')}));
      answer(Ok(_space([lea])));
      changes.add(null);
      await settle();

      verify(() => get(linked: const {StudentId('s1')})).called(1);
      expect(cubit.state.status, FamilyStatus.ready);
      expect(cubit.state.space!.children, [lea]);
      expect(cubit.state.selected, lea.id);
    },
  );

  // Limite connue de FB6 (ADR 0024, notes FB6), côté écran. Test unitaire à
  // doubles, pas une mesure à l'émulateur : le lien relu ne porte plus le
  // groupe g1 mais `CheckFamilyAccess` ne regarde que les fiches
  // (`AccessGranted`), et la portée de session (figée à la connexion) fait
  // encore lire les séances de g1. L'écran garde donc la séance du groupe
  // retiré. FB7 relira la portée : ce test devra alors casser.
  test(
    'known limit: a group removed from the link keeps its sessions on screen '
    'until FB7',
    () async {
      final session = FamilySession(
        id: 'ss-g1',
        title: 'Séance du groupe retiré',
        date: DateTime(2026, 10, 20),
        audience: Audience.children,
        groupName: 'Mardi',
      );
      answer(Ok(_space([lea], [session])));
      await cubit.load();
      expect(cubit.state.space!.upcoming, [session]);

      // Le club retire g1 du lien ; la fiche reste liée : l'accès est accordé.
      when(() => access())
          .thenAnswer((_) async => const AccessGranted({StudentId('s1')}));
      changes.add(null);
      await settle();

      expect(cubit.state.status, FamilyStatus.ready);
      expect(cubit.state.space!.upcoming, [session]);
    },
  );

  test('a revoked space does not reload any more', () async {
    when(() => access()).thenAnswer((_) async => const AccessRevoked());
    answer(const Err(_denied));
    await cubit.load();
    clearInteractions(get);

    await cubit.load();

    verifyNever(() => get(linked: any(named: 'linked')));
    expect(cubit.state.status, FamilyStatus.revoked);
  });

  test(
    'an unreachable server keeps the data shown and marks it stale',
    () async {
      answer(Ok(_space([lea])));
      await cubit.load();

      answer(const Err(_unavailable));
      changes.add(null);
      await settle();

      expect(cubit.state.status, FamilyStatus.ready);
      expect(cubit.state.stale, isTrue);
      expect(cubit.state.space!.children, [lea]);

      answer(Ok(_space([lea])));
      changes.add(null);
      await settle();
      expect(cubit.state.stale, isFalse);
    },
  );

  test(
    'an unreachable server at the first load fails; retrying restarts',
    () async {
      answer(const Err(_unavailable));
      await cubit.load();
      expect(cubit.state.status, FamilyStatus.failed);
      expect(cubit.state.failure, _unavailable);

      answer(Ok(_space([lea])));
      await cubit.load();

      expect(cubit.state.status, FamilyStatus.ready);
      verify(() => watch()).called(2);
    },
  );

  test('closing releases the subscription', () async {
    answer(Ok(_space([lea])));
    await cubit.load();
    expect(changes.hasListener, isTrue);

    await cubit.close();

    expect(changes.hasListener, isFalse);
  });
}
