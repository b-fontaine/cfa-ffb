// Génère les icônes de l'application web installable (app/web/icons, favicon).
//
//   dart run scripts/generate_pwa_icons.dart          écrit les PNG
//   dart run scripts/generate_pwa_icons.dart --check  vérifie qu'ils sont à jour
//
// Dessin : une bille noire sur le tapis bleu du thème, avec son disque blanc
// et un reflet. Aucune dépendance (rasterisation par suréchantillonnage,
// encodeur PNG minimal) : le résultat est déterministe octet pour octet.
//
// - `Icon-192.png`, `Icon-512.png` (purpose « any ») : bille à 64 % de la
//   largeur ;
// - `Icon-maskable-*.png` (purpose « maskable ») : fond plein, bille à 46 %
//   (zone de sécurité : un cercle de 80 % au centre) ;
// - `favicon.png` : 32 px.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Bleu tapis (`primary` du thème clair, `app_color_schemes.dart`).
const _cloth = (0x19, 0x64, 0xAF);
const _clothShade = (0x0D, 0x32, 0x58);
const _ball = (0x10, 0x16, 0x1D);
const _white = (0xF7, 0xF9, 0xFC);

const _supersampling = 4;

final String _root = File.fromUri(Platform.script).parent.parent.path;

typedef _Spec = ({String file, int size, double ballRatio});

const _specs = <_Spec>[
  (file: 'icons/Icon-192.png', size: 192, ballRatio: 0.64),
  (file: 'icons/Icon-512.png', size: 512, ballRatio: 0.64),
  (file: 'icons/Icon-maskable-192.png', size: 192, ballRatio: 0.46),
  (file: 'icons/Icon-maskable-512.png', size: 512, ballRatio: 0.46),
  (file: 'favicon.png', size: 32, ballRatio: 0.78),
];

void main(List<String> args) {
  final check = args.contains('--check');
  if (args.any((a) => a != '--check')) {
    stderr.writeln(
      'Usage : dart run scripts/generate_pwa_icons.dart [--check]',
    );
    exit(2);
  }
  var stale = false;
  for (final spec in _specs) {
    final bytes = render(spec.size, spec.ballRatio);
    final file = File('$_root/app/web/${spec.file}');
    if (check) {
      if (!file.existsSync() || !_same(file.readAsBytesSync(), bytes)) {
        stderr.writeln('Icône périmée : app/web/${spec.file}');
        stale = true;
      }
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    }
  }
  if (stale) {
    stderr.writeln('Régénérer : dart run scripts/generate_pwa_icons.dart');
    exit(1);
  }
  stdout.writeln(check ? 'Icônes web à jour.' : 'Icônes web écrites.');
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// PNG RGB carré de [size] px (fond plein : pas de transparence, donc pas de
/// coins noirs une fois masqué par le système).
Uint8List render(int size, double ballRatio) {
  final radius = size * ballRatio / 2;
  final centre = size / 2;
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filtre « aucun »
    for (var x = 0; x < size; x++) {
      var r = 0.0, g = 0.0, b = 0.0;
      for (var sy = 0; sy < _supersampling; sy++) {
        for (var sx = 0; sx < _supersampling; sx++) {
          final px = x + (sx + 0.5) / _supersampling - centre;
          final py = y + (sy + 0.5) / _supersampling - centre;
          final (cr, cg, cb) = _colorAt(px, py, radius);
          r += cr;
          g += cg;
          b += cb;
        }
      }
      const n = _supersampling * _supersampling;
      raw
        ..addByte((r / n).round())
        ..addByte((g / n).round())
        ..addByte((b / n).round());
    }
  }
  return _png(size, raw.toBytes());
}

(int, int, int) _colorAt(double x, double y, double radius) {
  final d = math.sqrt(x * x + y * y);
  // Ombre portée de la bille, légèrement décalée vers le bas.
  final shadow = math.sqrt(x * x + (y - radius * 0.08) * (y - radius * 0.08));
  if (d <= radius) {
    // Reflet : petit disque clair en haut à gauche.
    final hx = x + radius * 0.38, hy = y + radius * 0.42;
    if (math.sqrt(hx * hx + hy * hy) <= radius * 0.14)
      return _mix(_ball, _white, 0.55);
    // Disque blanc central (le numéro de la bille).
    if (d <= radius * 0.46) return _white;
    return _ball;
  }
  if (shadow <= radius * 1.04) return _mix(_cloth, _clothShade, 0.45);
  return _cloth;
}

(int, int, int) _mix((int, int, int) a, (int, int, int) b, double t) => (
  (a.$1 + (b.$1 - a.$1) * t).round(),
  (a.$2 + (b.$2 - a.$2) * t).round(),
  (a.$3 + (b.$3 - a.$3) * t).round(),
);

Uint8List _png(int size, Uint8List raw) {
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = type.codeUnits;
    out
      ..add(_u32(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_u32(_crc32([...typeBytes, ...data])));
  }

  chunk('IHDR', [..._u32(size), ..._u32(size), 8, 2, 0, 0, 0]);
  chunk('IDAT', ZLibCodec(level: 9).encode(raw));
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
];

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 255] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
