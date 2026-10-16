import 'package:billard_cfa/features/app_update/presentation/bloc/app_update_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_update_source.dart';

void main() {
  late FakeAppUpdateSource source;

  AppUpdateCubit makeCubit() {
    final cubit = AppUpdateCubit(source);
    addTearDown(cubit.close);
    return cubit;
  }

  tearDown(() => source.close());

  test('shows nothing while no version is waiting', () {
    source = FakeAppUpdateSource();

    final state = makeCubit().state;

    expect(state.available, isFalse);
    expect(state.visible, isFalse);
  });

  test('starts visible when a version already waits', () {
    source = FakeAppUpdateSource(available: true);

    expect(makeCubit().state.visible, isTrue);
  });

  test('becomes visible when the browser installs a new version', () {
    source = FakeAppUpdateSource();
    final cubit = makeCubit();

    source.emit(available: true);

    expect(cubit.state.visible, isTrue);
  });

  test('"later" hides the banner until the next page load', () {
    source = FakeAppUpdateSource(available: true);
    final cubit = makeCubit()..dismiss();

    expect(cubit.state.available, isTrue);
    expect(cubit.state.visible, isFalse);
  });

  test('a dismissed banner stays hidden when the same version is repeated', () {
    source = FakeAppUpdateSource(available: true);
    final cubit = makeCubit()..dismiss();

    source.emit(available: true);

    expect(cubit.state.visible, isFalse);
  });

  test('a withdrawn then new version asks for attention again', () {
    source = FakeAppUpdateSource(available: true);
    final cubit = makeCubit()..dismiss();

    source
      ..emit(available: false)
      ..emit(available: true);

    expect(cubit.state.visible, isTrue);
  });

  test('a dismissed banner disappears when the version is withdrawn', () {
    source = FakeAppUpdateSource(available: true);
    final cubit = makeCubit()..dismiss();

    source.emit(available: false);

    expect(cubit.state.available, isFalse);
    expect(cubit.state.visible, isFalse);
  });

  test('dismissing without a waiting version shows nothing', () {
    source = FakeAppUpdateSource();
    final cubit = makeCubit()..dismiss();

    expect(cubit.state.visible, isFalse);
  });

  test('apply still works after "later"', () async {
    source = FakeAppUpdateSource(available: true);
    final cubit = makeCubit()..dismiss();

    await cubit.apply();

    expect(source.applyCalls, 1);
  });

  test('apply asks the source to activate the version', () async {
    source = FakeAppUpdateSource(available: true);
    final cubit = makeCubit();

    await cubit.apply();

    expect(source.applyCalls, 1);
  });
}
