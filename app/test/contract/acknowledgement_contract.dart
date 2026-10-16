import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

AlertAcknowledgement _acknowledgement(
  String id, {
  String student = 's1',
  int number = 1,
  String lastAttempt = 'p3',
  int dayOfMonth = 5,
}) => AlertAcknowledgement(
  id: AcknowledgementId(id),
  studentId: StudentId(student),
  exercise: ref('puissance', number),
  lastAttemptId: AttemptId(lastAttempt),
  date: day(dayOfMonth),
);

/// Suite unique du port [AcknowledgementRepository], exécutée contre chaque
/// implémentation (même démarche que `acquisitionContract`).
void acknowledgementContract(
  String label,
  Future<
    ({AcknowledgementRepository repository, Future<void> Function() close})
  >
  Function()
  open,
) {
  group('$label : contrat des acquittements d’alertes', () {
    late AcknowledgementRepository repository;
    late Future<void> Function() close;

    setUp(() async {
      final opened = await open();
      repository = opened.repository;
      close = opened.close;
    });
    tearDown(() => close());

    test(
      'stores and reads the acknowledgements of a student, oldest first',
      () async {
        await repository.add(_acknowledgement('k2', number: 2, dayOfMonth: 8));
        await repository.add(_acknowledgement('k1'));
        await repository.add(_acknowledgement('k3', student: 's2'));

        final mine = await repository.forStudent(const StudentId('s1'));

        expect(mine.map((a) => a.id.value), ['k1', 'k2']);
        expect(mine.first.exercise, ref('puissance', 1));
        expect(mine.first.lastAttemptId, const AttemptId('p3'));
        expect(mine.first.date, day(5));
        expect(await repository.all(), hasLength(3));
      },
    );

    test('add of a known id replaces the acknowledgement', () async {
      await repository.add(_acknowledgement('k1'));
      await repository.add(_acknowledgement('k1', lastAttempt: 'p4'));

      final all = await repository.all();

      expect(all, hasLength(1));
      expect(all.single.lastAttemptId, const AttemptId('p4'));
    });

    test(
      'delete removes the acknowledgement and ignores an unknown id',
      () async {
        await repository.add(_acknowledgement('k1'));
        await repository.add(_acknowledgement('k2', number: 2));

        await repository.delete(const AcknowledgementId('k1'));
        await repository.delete(const AcknowledgementId('absent'));

        expect((await repository.all()).map((a) => a.id.value), ['k2']);
        expect(
          await repository.forStudent(const StudentId('s1')),
          hasLength(1),
        );
      },
    );

    test('an acknowledgement deleted then added again is back', () async {
      await repository.add(_acknowledgement('k1'));
      await repository.delete(const AcknowledgementId('k1'));
      await repository.add(_acknowledgement('k1'));

      expect(await repository.all(), hasLength(1));
    });

    test(
      'eraseStudent erases every acknowledgement of the student only',
      () async {
        await repository.add(_acknowledgement('k1'));
        await repository.add(_acknowledgement('k2', number: 2));
        await repository.add(_acknowledgement('k3', student: 's2'));
        await repository.delete(const AcknowledgementId('k2'));

        await repository.eraseStudent(const StudentId('s1'));

        expect(await repository.forStudent(const StudentId('s1')), isEmpty);
        expect((await repository.all()).map((a) => a.id.value), ['k3']);
      },
    );

    test('eraseAll erases every acknowledgement of the club', () async {
      await repository.add(_acknowledgement('k1'));
      await repository.add(_acknowledgement('k3', student: 's2'));
      await repository.delete(const AcknowledgementId('k3'));

      await repository.eraseAll();

      expect(await repository.all(), isEmpty);
    });
  });
}
