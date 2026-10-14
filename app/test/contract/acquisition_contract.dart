import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

BlockAcquisition _acquisition(
  String id, {
  String student = 's1',
  String block = 'posture',
  int day = 5,
}) => BlockAcquisition(
  id: AcquisitionId(id),
  studentId: StudentId(student),
  blockId: block,
  date: DateTime(2026, 10, day),
  source: AcquisitionSource.placement,
);

/// Suite unique du port [AcquisitionRepository], exécutée contre chaque
/// implémentation (même démarche que `repositoryContract`).
void acquisitionContract(
  String label,
  Future<({AcquisitionRepository repository, Future<void> Function() close})>
  Function()
  open,
) {
  group('$label : contrat des blocs acquis', () {
    late AcquisitionRepository repository;
    late Future<void> Function() close;

    setUp(() async {
      final opened = await open();
      repository = opened.repository;
      close = opened.close;
    });
    tearDown(() => close());

    test('stores and reads the markers of a student, oldest first', () async {
      await repository.add(_acquisition('q2', block: 'puissance', day: 8));
      await repository.add(_acquisition('q1'));
      await repository.add(_acquisition('q3', student: 's2'));

      final mine = await repository.forStudent(const StudentId('s1'));

      expect(mine.map((a) => a.id.value), ['q1', 'q2']);
      expect(mine.first.date, DateTime(2026, 10, 5));
      expect(mine.first.source, AcquisitionSource.placement);
      expect(await repository.all(), hasLength(3));
    });

    test('add of a known id replaces the marker', () async {
      await repository.add(_acquisition('q1'));
      await repository.add(_acquisition('q1', day: 9));

      final all = await repository.all();

      expect(all, hasLength(1));
      expect(all.single.date, DateTime(2026, 10, 9));
    });

    test('delete removes the marker and ignores an unknown id', () async {
      await repository.add(_acquisition('q1'));
      await repository.add(_acquisition('q2', block: 'puissance'));

      await repository.delete(const AcquisitionId('q1'));
      await repository.delete(const AcquisitionId('absent'));

      final left = await repository.all();
      expect(left.map((a) => a.id.value), ['q2']);
      expect(await repository.forStudent(const StudentId('s1')), hasLength(1));
    });

    test('eraseStudent erases every marker of the student only', () async {
      await repository.add(_acquisition('q1'));
      await repository.add(_acquisition('q2', block: 'puissance'));
      await repository.add(_acquisition('q3', student: 's2'));
      await repository.delete(const AcquisitionId('q2'));

      await repository.eraseStudent(const StudentId('s1'));

      expect(await repository.forStudent(const StudentId('s1')), isEmpty);
      expect((await repository.all()).map((a) => a.id.value), ['q3']);
    });
  });
}
