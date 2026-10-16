import 'dart:async';

import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_fullscreen_controller.dart';

void main() {
  late FakeFullscreenController controller;

  FullscreenCubit makeCubit() {
    final cubit = FullscreenCubit(controller);
    addTearDown(cubit.close);
    return cubit;
  }

  tearDown(() => controller.close());

  test('starts from what the controller reports', () {
    controller = FakeFullscreenController(active: true);

    expect(
      makeCubit().state,
      const FullscreenState(supported: true, active: true),
    );
  });

  test('reports an unsupported device', () {
    controller = FakeFullscreenController(supported: false);

    expect(makeCubit().state.supported, isFalse);
  });

  test('toggle enters the full screen when inactive', () async {
    controller = FakeFullscreenController();
    final cubit = makeCubit();

    await cubit.toggle();

    expect(controller.enterCalls, 1);
    expect(controller.exitCalls, 0);
    expect(cubit.state.active, isTrue);
  });

  test('toggle leaves the full screen when active', () async {
    controller = FakeFullscreenController(active: true);
    final cubit = makeCubit();

    await cubit.toggle();

    expect(controller.exitCalls, 1);
    expect(controller.enterCalls, 0);
    expect(cubit.state.active, isFalse);
  });

  test('asks the platform before any await, in the user gesture (enter)', () {
    controller = FakeFullscreenController();
    final cubit = makeCubit();

    // Pas de `await` : l'appel doit déjà être parti.
    unawaited(cubit.toggle());

    expect(controller.enterCalls, 1);
  });

  test('asks the platform before any await, in the user gesture (exit)', () {
    controller = FakeFullscreenController(active: true);
    final cubit = makeCubit();

    unawaited(cubit.toggle());

    expect(controller.exitCalls, 1);
  });

  test('follows a change that does not come from the app', () {
    controller = FakeFullscreenController(active: true);
    final cubit = makeCubit();

    controller.emit(active: false);

    expect(cubit.state.active, isFalse);
  });

  test('does nothing on a device without full screen', () async {
    controller = FakeFullscreenController(supported: false);
    final cubit = makeCubit();

    await cubit.toggle();

    expect(controller.enterCalls, 0);
    expect(controller.exitCalls, 0);
  });

  test('stops listening once closed', () async {
    controller = FakeFullscreenController();
    final cubit = FullscreenCubit(controller);
    await cubit.close();

    expect(() => controller.emit(active: true), returnsNormally);
    expect(cubit.state.active, isFalse);
  });
}
