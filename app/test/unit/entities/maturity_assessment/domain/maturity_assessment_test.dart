import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

MaturityAssessment build(
  int concentration,
  int endurance,
  int frustration, {
  String? comment,
}) => MaturityAssessment(
  id: const AssessmentId('m'),
  studentId: const StudentId('s'),
  date: day(5),
  concentration: concentration,
  endurance: endurance,
  frustration: frustration,
  comment: comment,
);

void main() {
  group('scores', () {
    test('accept the bounds 1 and 4', () {
      expect(build(1, 4, 1).endurance, 4);
    });

    test('refuse 0 on each criterion', () {
      expect(() => build(0, 2, 2), violation(InvariantCode.scoreOutOfRange));
      expect(() => build(2, 0, 2), violation(InvariantCode.scoreOutOfRange));
      expect(() => build(2, 2, 0), violation(InvariantCode.scoreOutOfRange));
    });

    test('refuse 5 on each criterion', () {
      expect(() => build(5, 2, 2), violation(InvariantCode.scoreOutOfRange));
      expect(() => build(2, 5, 2), violation(InvariantCode.scoreOutOfRange));
      expect(() => build(2, 2, 5), violation(InvariantCode.scoreOutOfRange));
    });
  });

  group('comment', () {
    test('is optional', () {
      expect(build(2, 2, 2).comment, isNull);
    });

    test('is kept as written up to the maximum length', () {
      final longest = 'x' * MaturityAssessment.maxCommentLength;

      expect(build(2, 2, 2, comment: 'Calme').comment, 'Calme');
      expect(build(2, 2, 2, comment: longest).comment, longest);
    });

    test('refuses a comment longer than the maximum length', () {
      final tooLong = 'x' * (MaturityAssessment.maxCommentLength + 1);

      expect(
        () => build(2, 2, 2, comment: tooLong),
        violation(InvariantCode.commentTooLong),
      );
    });
  });

  group('readinessHint', () {
    final config = RulesConfig();

    test('is true when all criteria reach 3', () {
      expect(build(3, 3, 3).readinessHint(config), isTrue);
      expect(build(4, 4, 3).readinessHint(config), isTrue);
    });

    test('is true when any single criterion exceeds the threshold', () {
      expect(build(4, 3, 3).readinessHint(config), isTrue);
      expect(build(3, 4, 3).readinessHint(config), isTrue);
      expect(build(3, 3, 4).readinessHint(config), isTrue);
    });

    test('is false when any criterion is 2', () {
      expect(build(2, 4, 4).readinessHint(config), isFalse);
      expect(build(4, 2, 4).readinessHint(config), isFalse);
      expect(build(4, 4, 2).readinessHint(config), isFalse);
    });

    test('follows the configured minimum score', () {
      final strict = RulesConfig(readinessMinScore: 4);

      expect(build(3, 3, 3).readinessHint(strict), isFalse);
      expect(build(4, 4, 4).readinessHint(strict), isTrue);
    });
  });
}
