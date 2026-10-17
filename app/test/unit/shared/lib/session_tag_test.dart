import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the closed list is the eight agreed labels, in display order', () {
    expect(SessionTag.values.map((tag) => tag.name), [
      'gameAppreciated',
      'instructionsToRephrase',
      'tooLong',
      'tooShort',
      'tooHard',
      'tooEasy',
      'toRedo',
      'equipmentLacking',
    ]);
  });

  group('tryParse', () {
    test('finds a tag by its stored code', () {
      for (final tag in SessionTag.values) {
        expect(SessionTag.tryParse(tag.name), tag);
      }
    });

    test('refuses anything else, free text included', () {
      expect(SessionTag.tryParse('Léa a pleuré'), isNull);
      expect(SessionTag.tryParse(''), isNull);
      expect(SessionTag.tryParse('TOOLONG'), isNull);
    });
  });

  group('encodeSessionTags', () {
    test('writes the codes as a JSON list in display order', () {
      expect(
        encodeSessionTags({SessionTag.toRedo, SessionTag.tooLong}),
        '["tooLong","toRedo"]',
      );
    });

    test('writes an empty set as an empty list', () {
      expect(encodeSessionTags(const {}), '[]');
    });
  });

  group('decodeSessionTags', () {
    test('reads back what was written', () {
      final tags = {SessionTag.gameAppreciated, SessionTag.equipmentLacking};
      expect(decodeSessionTags(encodeSessionTags(tags)), tags);
    });

    test('strict mode refuses an unknown code, a duplicate or a non-list', () {
      expect(() => decodeSessionTags('["nope"]'), throwsFormatException);
      expect(
        () => decodeSessionTags('["tooLong","tooLong"]'),
        throwsFormatException,
      );
      expect(() => decodeSessionTags('{"a":1}'), throwsFormatException);
      expect(() => decodeSessionTags('[3]'), throwsFormatException);
      expect(() => decodeSessionTags('pas du json'), throwsFormatException);
    });

    test('lenient mode keeps the known codes and never throws', () {
      expect(decodeSessionTags('["nope","tooLong"]', strict: false), {
        SessionTag.tooLong,
      });
      expect(decodeSessionTags('pas du json', strict: false), isEmpty);
      expect(decodeSessionTags('{"a":1}', strict: false), isEmpty);
    });
  });
}
