import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements SessionRepository;

class _FixedIds implements IdGenerator {
  @override
  String next() => 'fixed-id';
}

void main() {
  late _MockRepository repository;
  late PlanSession planSession;

  setUpAll(() {
    registerFallbackValue(
      const Session(id: '', title: '', audience: Audience.children),
    );
  });

  setUp(() {
    repository = _MockRepository();
    when(() => repository.add(any())).thenAnswer((_) async {});
    planSession = PlanSession(repository, _FixedIds());
  });

  test('stores a trimmed session with a generated id', () async {
    final session = await planSession(
      title: '  Posture  ',
      audience: Audience.children,
    );

    const expected = Session(
      id: 'fixed-id',
      title: 'Posture',
      audience: Audience.children,
    );
    expect(session, expected);
    verify(() => repository.add(expected)).called(1);
  });

  test('keeps the chosen catalogue session', () async {
    final session = await planSession(
      title: 'Demi-bille',
      audience: Audience.adults,
      sheetId: SheetId('demi-bille-2'),
    );

    expect(session.sheetId?.value, 'demi-bille-2');
    verify(() => repository.add(session)).called(1);
  });

  test('rejects a blank title without storing anything', () async {
    await expectLater(
      planSession(title: '   ', audience: Audience.adults),
      throwsA(isA<InvalidSessionTitle>()),
    );

    verifyNever(() => repository.add(any()));
  });
}
