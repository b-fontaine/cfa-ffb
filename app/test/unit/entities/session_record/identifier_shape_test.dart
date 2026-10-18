import 'package:billard_cfa/entities/session_record/domain/sitting_id.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// La forme des identifiants est une **hypothèse de sécurité** de
/// `firestore.rules` (`mayProbeAbsent`) : un enseignant ne peut lire un
/// document ABSENT de `records` ou `sessions` que si son identifiant est
/// aléatoire (sans `_` : rien à deviner) ou s'il commence par l'un de ses
/// groupes avant le premier `_`. Si une forme change, l'identifiant
/// déterministe `groupe_AAAAMMJJ_séance` redeviendrait un oracle d'existence
/// (« le groupe g1 a-t-il tenu une séance ce jour-là ? ») : ces tests la
/// figent.
void main() {
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  group('free identifiers (UUID, no underscore)', () {
    test('a generated identifier is a UUID v4 without an underscore', () {
      final generator = UuidV4Generator();

      for (var i = 0; i < 500; i++) {
        final id = generator.next();
        expect(id, matches(uuid));
        expect(id, isNot(contains('_')));
      }
    });

    test('a group, a record or a planned session of the application gets '
        'such an identifier: the rule reads the group before the first '
        'underscore', () {
      // Les groupes et les saisies libres sont nommés par `IdGenerator` : le
      // premier segment d'un identifiant déterministe est donc le groupe tout
      // entier.
      final group = GroupId(UuidV4Generator().next());
      final id = sittingId(group, DateTime(2026, 10, 5), SheetId('posture-1'));

      expect(id.value.split('_').first, group.value);
    });

    test(
      'the sequential identifiers of the tests have no underscore either',
      () {
        final generator = SequentialIdGenerator();

        expect(generator.next(), isNot(contains('_')));
      },
    );
  });

  group('sitting identifiers always contain an underscore', () {
    test('whatever the group, the day or the catalogue session', () {
      final generator = UuidV4Generator();
      for (final sheet in ['posture-1', 'demi-bille-2', 'a', 'puissance-12']) {
        for (final day in [
          DateTime(2026),
          DateTime(2026, 10, 5, 23, 59),
          DateTime(1999, 12, 31),
        ]) {
          final id = sittingId(
            GroupId(generator.next()),
            day,
            SheetId(sheet),
          ).value;

          // Au moins deux `_` : groupe, jour, séance.
          expect('_'.allMatches(id), hasLength(greaterThanOrEqualTo(2)));
          expect(id.split('_').first, matches(uuid));
        }
      }
    });
  });
}
