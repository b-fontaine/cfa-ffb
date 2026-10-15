import 'package:billard_cfa/entities/settings/data/in_memory_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/load_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/reset_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/save_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/settings_field.dart';
import 'package:billard_cfa/features/manage_settings/presentation/bloc/settings_bloc.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySettingsRepository repository;
  late RulesStore store;

  setUp(() {
    repository = InMemorySettingsRepository();
    store = RulesStore(RulesConfig());
  });

  SettingsBloc build() => SettingsBloc(
    LoadSettings(repository, store),
    SaveSettings(repository, store),
    ResetSettings(repository, store),
  );

  Future<SettingsBloc> started() async {
    final bloc = build()..add(const SettingsEvent.started());
    await bloc.stream.firstWhere((s) => s.status == SettingsStatus.editing);
    return bloc;
  }

  test('starts loading, then shows the saved values', () async {
    final bloc = build();
    expect(bloc.state.status, SettingsStatus.loading);

    bloc.add(const SettingsEvent.started());
    final state = await bloc.stream.firstWhere(
      (s) => s.status == SettingsStatus.editing,
    );

    expect(state.saved, ClubSettings.defaults);
    expect(state.draft, ClubSettings.defaults);
    expect(state.isDirty, isFalse);
    await bloc.close();
  });

  test('a change only edits the draft', () async {
    final bloc = await started();

    bloc.add(
      const SettingsEvent.changed(
        field: SettingsField.passesRequired,
        value: 3,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.draft?.passesRequired, 3);
    expect(bloc.state.saved?.passesRequired, 5);
    expect(bloc.state.isDirty, isTrue);
    expect(await repository.load(), ClubSettings.defaults);
    expect(store.current.passesRequired, 5);
    await bloc.close();
  });

  test('changing back to the saved value is not a modification', () async {
    final bloc = await started();

    bloc
      ..add(
        const SettingsEvent.changed(
          field: SettingsField.passesRequired,
          value: 3,
        ),
      )
      ..add(
        const SettingsEvent.changed(
          field: SettingsField.passesRequired,
          value: 5,
        ),
      );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.isDirty, isFalse);
    await bloc.close();
  });

  test('saving writes, replaces the rules and reports saved', () async {
    final bloc = await started();
    bloc
      ..add(
        const SettingsEvent.changed(
          field: SettingsField.backupReminderDays,
          value: 7,
        ),
      )
      ..add(const SettingsEvent.saveRequested());

    final state = await bloc.stream.firstWhere(
      (s) => s.status == SettingsStatus.saved,
    );

    expect(state.saved?.backupReminderDays, 7);
    expect(state.isDirty, isFalse);
    expect((await repository.load()).backupReminderDays, 7);
    expect(store.current.backupReminderDays, 7);
    await bloc.close();
  });

  test('refused settings keep the draft and write nothing', () async {
    store.current = RulesConfig(persistentAlertThreshold: 3);
    final bloc = await started();
    bloc
      ..add(
        const SettingsEvent.changed(
          field: SettingsField.alertThreshold,
          value: 4,
        ),
      )
      ..add(const SettingsEvent.saveRequested());

    final state = await bloc.stream.firstWhere(
      (s) => s.status == SettingsStatus.failed,
    );

    expect(
      state.failure,
      isA<InvariantViolation>().having(
        (v) => v.code,
        'code',
        InvariantCode.invalidRules,
      ),
    );
    expect(state.draft?.alertThreshold, 4);
    expect(state.saved?.alertThreshold, 3);
    expect(await repository.load(), ClubSettings.defaults);
    expect(store.current.alertThreshold, 3);
    await bloc.close();
  });

  test('a new change after a refusal clears the message', () async {
    store.current = RulesConfig(persistentAlertThreshold: 3);
    final bloc = await started();
    bloc
      ..add(
        const SettingsEvent.changed(
          field: SettingsField.alertThreshold,
          value: 4,
        ),
      )
      ..add(const SettingsEvent.saveRequested());
    await bloc.stream.firstWhere((s) => s.status == SettingsStatus.failed);

    bloc.add(
      const SettingsEvent.changed(
        field: SettingsField.alertThreshold,
        value: 3,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (s) => s.status == SettingsStatus.editing,
    );

    expect(state.failure, isNull);
    await bloc.close();
  });

  test('confirming a reset restores the defaults', () async {
    await repository.save(ClubSettings.defaults.copyWith(passesRequired: 3));
    store.current = ClubSettings.defaults
        .copyWith(passesRequired: 3)
        .applyTo(store.current);
    final bloc = await started();
    expect(bloc.state.saved?.passesRequired, 3);

    bloc.add(const SettingsEvent.resetConfirmed());
    final state = await bloc.stream.firstWhere(
      (s) => s.status == SettingsStatus.reset,
    );

    expect(state.saved, ClubSettings.defaults);
    expect(state.draft, ClubSettings.defaults);
    expect(store.current.passesRequired, 5);
    await bloc.close();
  });
}
