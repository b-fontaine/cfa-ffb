import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/firestore_world.dart';

void main() {
  late FirestoreWorld world;
  late FirestoreSettingsRepository repository;

  const custom = ClubSettings(
    passesRequired: 3,
    alertThreshold: 4,
    recallStaleSessions: 6,
    groupFailureSharePercent: 30,
    backupReminderDays: 14,
  );

  setUp(() {
    world = FirestoreWorld()..act('c1', Role.director);
    repository = FirestoreSettingsRepository(world.club);
  });

  test('lives in the single document of the active club', () async {
    await repository.save(custom);

    expect(world.paths, ['clubs/c1/settings/main']);
  });

  test('writes exactly the fields firestore.rules allows', () async {
    await repository.save(custom);

    expect(world.documents.read('clubs/c1/settings/main'), {
      'passesRequired': 3,
      'alertThreshold': 4,
      'recallStaleSessions': 6,
      'groupFailureSharePercent': 30,
      'backupReminderDays': 14,
    });
  });

  test('every club has its own settings', () async {
    await repository.save(custom);
    world.act('c2', Role.director);

    expect(await repository.load(), ClubSettings.defaults);
    await repository.save(custom.copyWith(passesRequired: 9));
    world.act('c1', Role.teacher);

    expect((await repository.load()).passesRequired, 3);
  });

  test('a missing field takes its default, an optional one too', () async {
    world.documents.seed('clubs/c1/settings/main', {
      'passesRequired': 7,
      'alertThreshold': 2,
      'recallStaleSessions': 5,
      'groupFailureSharePercent': 40,
    });

    final loaded = await repository.load();

    expect(loaded.passesRequired, 7);
    expect(loaded.backupReminderDays, ClubSettings.defaults.backupReminderDays);
  });

  test('a field of the wrong type is a failure that names the field', () async {
    world.documents.seed('clubs/c1/settings/main', {'passesRequired': '5'});

    await expectLater(
      repository.load(),
      throwsA(
        isA<ServiceFailure>()
            .having((f) => f.code, 'code', ServiceFailureCode.other)
            .having((f) => f.detail, 'detail', contains('passesRequired')),
      ),
    );
  });

  test('reset deletes the document, and is harmless without it', () async {
    await repository.reset();
    await repository.save(custom);
    await repository.reset();

    expect(world.paths, isEmpty);
  });

  test('without an active club nothing is read or written', () async {
    world.scope.deactivateClub();

    await expectLater(repository.load(), throwsA(isA<ServiceFailure>()));
    await expectLater(repository.save(custom), throwsA(isA<ServiceFailure>()));
    await expectLater(repository.reset(), throwsA(isA<ServiceFailure>()));
    expect(world.documents.reads, 0);
    expect(world.documents.commits, 0);
  });

  test('a rule refusal and a network failure are told apart', () async {
    world.documents.failing = StoreFailureCode.permissionDenied;
    await expectLater(
      repository.save(custom),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.denied,
        ),
      ),
    );

    world.documents.failing = StoreFailureCode.unavailable;
    await expectLater(
      repository.load(),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      ),
    );
  });
}
