import 'package:billard_cfa/features/record_results/presentation/bloc/session_date_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 12);

  blocTest<SessionDateCubit, DateTime>(
    'starts on the given day',
    build: () => SessionDateCubit(today),
    verify: (cubit) => expect(cubit.state, today),
  );

  blocTest<SessionDateCubit, DateTime>(
    'changes the day of the session',
    build: () => SessionDateCubit(today),
    act: (cubit) => cubit.changed(DateTime(2026, 10, 5)),
    expect: () => [DateTime(2026, 10, 5)],
  );
}
