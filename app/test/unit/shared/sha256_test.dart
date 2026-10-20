import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vecteurs de référence (FIPS 180-4 et `hashlib` de Python) ; le même calcul
/// est vérifié en JavaScript (dart2js) avant d'être retenu : l'import tourne
/// aussi dans le navigateur.
void main() {
  test('the empty text', () {
    expect(
      sha256Hex(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });

  test('abc', () {
    expect(
      sha256Hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('a message spanning two blocks', () {
    expect(
      sha256Hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
  });

  test('multi-byte characters are hashed as UTF-8', () {
    expect(
      sha256Hex('é' * 1000),
      '75628d88c411e2c7a3e1cbb3f0eb5498e51455875142fedd62677987cdecf107',
    );
  });

  test('the same content always gives the same 64-character digest', () {
    expect(sha256Hex('x'), sha256Hex('x'));
    expect(sha256Hex('x'), isNot(sha256Hex('y')));
    expect(sha256Hex('x'), hasLength(64));
  });
}
