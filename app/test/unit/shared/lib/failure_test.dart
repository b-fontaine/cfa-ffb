import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wraps a returned value in Ok', () async {
    final result = await runGuarded(() async => 42);

    expect(result, isA<Ok<int>>().having((r) => r.value, 'value', 42));
  });

  test('turns a thrown InvariantViolation into Err', () async {
    final result = await runGuarded<int>(
      () async => throw const InvariantViolation(InvariantCode.blankName),
    );

    expect(
      result,
      isA<Err<int>>().having(
        (r) => r.failure,
        'failure',
        isA<InvariantViolation>().having(
          (f) => f.code,
          'code',
          InvariantCode.blankName,
        ),
      ),
    );
  });

  test('turns a thrown NotFound into Err', () async {
    final result = await runGuarded<int>(
      () async => throw const NotFound('student', 'x'),
    );

    expect(
      result,
      isA<Err<int>>().having(
        (r) => r.failure,
        'failure',
        isA<NotFound>()
            .having((f) => f.kind, 'kind', 'student')
            .having((f) => f.id, 'id', 'x'),
      ),
    );
  });

  test('does not swallow unexpected errors', () {
    expect(
      runGuarded<int>(() async => throw StateError('bug')),
      throwsStateError,
    );
  });

  test('describes failures for diagnostics', () {
    expect(
      const InvariantViolation(InvariantCode.negativePotted).toString(),
      'InvariantViolation(negativePotted)',
    );
    expect(const NotFound('group', 'g1').toString(), 'NotFound(group, g1)');
    expect(
      const ServiceFailure(ServiceFailureCode.unavailable).toString(),
      'ServiceFailure(unavailable)',
    );
    expect(
      const ServiceFailure(
        ServiceFailureCode.denied,
        'permission-denied',
      ).toString(),
      'ServiceFailure(denied: permission-denied)',
    );
  });

  test('a switch over Failure is exhaustive', () {
    String describe(Failure failure) => switch (failure) {
      InvariantViolation() => 'invariant',
      NotFound() => 'not-found',
      ServiceFailure() => 'service',
    };

    expect(describe(const NotFound('a', 'b')), 'not-found');
    expect(
      describe(const ServiceFailure(ServiceFailureCode.denied)),
      'service',
    );
    expect(
      describe(const InvariantViolation(InvariantCode.blankName)),
      'invariant',
    );
  });
}
