import 'package:billard_cfa/features/suggest_session/domain/get_exercise_sheet.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late GetExerciseSheet getSheet;

  setUp(() {
    getSheet = GetExerciseSheet(DomainWorld().catalogueRepository);
  });

  test('gives the exercise with its block', () async {
    final sheet = ok(await getSheet(ref('b', 2)));

    expect(sheet.block.id, 'b');
    expect(sheet.block.title, 'Bloc b');
    expect(sheet.spec.ref, ref('b', 2));
    expect(sheet.spec.rate, rate());
  });

  test('refuses an unknown exercise', () async {
    final result = await getSheet(ref('b', 9));

    expect(codeOf(result), InvariantCode.unknownExercise);
  });

  test('refuses an unknown block', () async {
    final result = await getSheet(ref('zzz', 1));

    expect(codeOf(result), InvariantCode.unknownExercise);
  });
}
