import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RunMode.defaultFor', () {
    test('leads a planned session', () {
      expect(RunMode.defaultFor(planned: true), RunMode.lead);
    });

    test('reviews a guide opened without a planned session', () {
      expect(RunMode.defaultFor(planned: false), RunMode.review);
    });
  });

  group('effects', () {
    test('review shows the provenance and unfolds the sections', () {
      expect(RunMode.review.showsProvenance, isTrue);
      expect(RunMode.review.expandsSections, isTrue);
    });

    test('lead hides the provenance badges and folds the sections', () {
      expect(RunMode.lead.showsProvenance, isFalse);
      expect(RunMode.lead.expandsSections, isFalse);
    });
  });

  group('RunMode.tryParse', () {
    test('reads the two address values', () {
      expect(RunMode.tryParse('lead'), RunMode.lead);
      expect(RunMode.tryParse('review'), RunMode.review);
    });

    test('ignores an absent or unknown value', () {
      expect(RunMode.tryParse(null), isNull);
      expect(RunMode.tryParse(''), isNull);
      expect(RunMode.tryParse('evil'), isNull);
      expect(RunMode.tryParse('Lead'), isNull);
    });
  });
}
