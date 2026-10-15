import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/load_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/reset_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/save_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/settings_field.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'settings_bloc.freezed.dart';
part 'settings_event.dart';
part 'settings_state.dart';

/// Écran Réglages : brouillon modifié par les compteurs, écrit seulement à
/// l'enregistrement. La validation est celle de `RulesConfig` (cas d'usage) :
/// un refus garde le brouillon et n'écrit rien.
@injectable
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._load, this._save, this._reset)
    : super(const SettingsState()) {
    on<SettingsStarted>(_onStarted);
    on<SettingsChanged>(_onChanged);
    on<SettingsSaveRequested>(_onSave);
    on<SettingsResetConfirmed>(_onReset);
  }

  final LoadSettings _load;
  final SaveSettings _save;
  final ResetSettings _reset;

  Future<void> _onStarted(
    SettingsStarted event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsState());
    switch (await _load()) {
      case Ok(:final value):
        emit(
          SettingsState(
            status: SettingsStatus.editing,
            saved: value,
            draft: value,
          ),
        );
      case Err(:final failure):
        emit(SettingsState(status: SettingsStatus.failed, failure: failure));
    }
  }

  void _onChanged(SettingsChanged event, Emitter<SettingsState> emit) {
    final draft = state.draft;
    if (draft == null) return;
    emit(
      state.copyWith(
        status: SettingsStatus.editing,
        draft: event.field.write(draft, event.value),
        failure: null,
      ),
    );
  }

  Future<void> _onSave(
    SettingsSaveRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null || state.status == SettingsStatus.saving) return;
    emit(state.copyWith(status: SettingsStatus.saving, failure: null));
    switch (await _save(draft)) {
      case Ok(:final value):
        emit(
          SettingsState(
            status: SettingsStatus.saved,
            saved: value,
            draft: value,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: SettingsStatus.failed, failure: failure));
    }
  }

  Future<void> _onReset(
    SettingsResetConfirmed event,
    Emitter<SettingsState> emit,
  ) async {
    if (state.status == SettingsStatus.saving) return;
    emit(state.copyWith(status: SettingsStatus.saving, failure: null));
    switch (await _reset()) {
      case Ok(:final value):
        emit(
          SettingsState(
            status: SettingsStatus.reset,
            saved: value,
            draft: value,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: SettingsStatus.failed, failure: failure));
    }
  }
}
