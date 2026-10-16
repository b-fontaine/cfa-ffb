import 'dart:async';

import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'fullscreen_cubit.freezed.dart';

@freezed
abstract class FullscreenState with _$FullscreenState {
  const factory FullscreenState({
    required bool supported,
    required bool active,
  }) = _FullscreenState;
}

/// État du plein écran, partagé par la présentation et le guide (ADR 0017) :
/// le contrôleur est unique, chaque écran lit son état par ce cubit.
@injectable
class FullscreenCubit extends Cubit<FullscreenState> {
  FullscreenCubit(this._controller)
    : super(
        FullscreenState(
          supported: _controller.isSupported,
          active: _controller.isActive,
        ),
      ) {
    _subscription = _controller.changes.listen(
      (active) => emit(state.copyWith(active: active)),
    );
  }

  final FullscreenController _controller;
  late final StreamSubscription<bool> _subscription;

  /// Entre ou sort du plein écran. L'appel à la plate-forme est fait avant
  /// tout `await` : le web l'exige dans le geste de l'utilisateur.
  Future<void> toggle() {
    if (!state.supported) return Future<void>.value();
    return state.active ? _controller.exit() : _controller.enter();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
