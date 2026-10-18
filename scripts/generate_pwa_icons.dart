// Génère les icônes de l'application pour toutes les plateformes cibles à
// partir de l'icône source `app/assets/images/animation-billard.png`
// (et `animation-billard.ico` pour Windows).
//
//   dart run scripts/generate_pwa_icons.dart          écrit les icônes
//   dart run scripts/generate_pwa_icons.dart --check  vérifie qu'elles sont à
//                                                     jour
//
// Aucune dépendance (décodeur PNG minimal, réduction par moyenne de surface,
// encodeur PNG minimal) : le résultat est déterministe octet pour octet.
//
// - web (`app/web`) : `Icon-192/512.png` (« any »), `Icon-maskable-*.png`
//   (fond plein : l'image est pleine page, son sujet tient dans le cercle de
//   sécurité de 80 %), `favicon.png` ;
// - Android : `mipmap-*/ic_launcher.png` (anciennes versions) et icône
//   adaptative (`ic_launcher_background.png` sur 108 dp, premier plan
//   transparent : le système en montre les 66 % centraux) ;
// - iOS : `AppIcon.appiconset` (carrés pleins, iOS arrondit) ;
// - macOS : `AppIcon.appiconset` (forme arrondie sur fond transparent, comme
//   le gabarit Apple : image à 80 % de la toile, rayon de 22,4 %) ;
// - Windows : copie de `animation-billard.ico`.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

final String _root = File.fromUri(Platform.script).parent.parent.path;
final String _app = '$_root/app';
final String _sourcePng = '$_app/assets/images/animation-billard.png';
final String _sourceIco = '$_app/assets/images/animation-billard.ico';

const _supersampling = 4;

/// Proportions du gabarit d'icône macOS (Big Sur) sur une toile de 1024.
const double _macContent = 824 / 1024;
const double _macRadius = 185.4 / 824;

/// Fichiers PNG carrés, chemins relatifs à `app/`.
const _web = <String, int>{
  'web/icons/Icon-192.png': 192,
  'web/icons/Icon-512.png': 512,
  'web/icons/Icon-maskable-192.png': 192,
  'web/icons/Icon-maskable-512.png': 512,
  'web/favicon.png': 32,
};

const _androidRes = 'android/app/src/main/res';
const _androidLegacy = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};
const _androidAdaptive = <String, int>{
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};
const _androidAdaptiveXml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@android:color/transparent"/>
</adaptive-icon>
''';

const _iosSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _iosIcons = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const _macSet = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const _macSizes = <int>[16, 32, 64, 128, 256, 512, 1024];

const _windowsIco = 'windows/runner/resources/app_icon.ico';

void main(List<String> args) {
  final check = args.contains('--check');
  if (args.any((a) => a != '--check')) {
    stderr.writeln(
      'Usage : dart run scripts/generate_pwa_icons.dart [--check]',
    );
    exit(2);
  }
  final outputs = _outputs();
  var stale = false;
  for (final MapEntry(key: path, value: bytes) in outputs.entries) {
    final file = File('$_app/$path');
    if (check) {
      if (!file.existsSync() || !_same(file.readAsBytesSync(), bytes)) {
        stderr.writeln('Icône périmée : app/$path');
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
  stdout.writeln(
    check
        ? 'Icônes à jour (${outputs.length} fichiers).'
        : 'Icônes écrites (${outputs.length} fichiers).',
  );
}

/// Tous les fichiers produits, indexés par chemin relatif à `app/`.
Map<String, Uint8List> _outputs() {
  final source = _decodePng(File(_sourcePng).readAsBytesSync());
  final squares = <int, Uint8List>{};
  Uint8List square(int size) =>
      squares.putIfAbsent(size, () => _png(size, _resize(source, size)));

  final out = <String, Uint8List>{};
  _web.forEach((path, size) => out[path] = square(size));
  _androidLegacy.forEach(
    (density, size) =>
        out['$_androidRes/mipmap-$density/ic_launcher.png'] = square(size),
  );
  _androidAdaptive.forEach(
    (density, size) =>
        out['$_androidRes/mipmap-$density/ic_launcher_background.png'] = square(
          size,
        ),
  );
  out['$_androidRes/mipmap-anydpi-v26/ic_launcher.xml'] = Uint8List.fromList(
    _androidAdaptiveXml.codeUnits,
  );
  _iosIcons.forEach((name, size) => out['$_iosSet/$name'] = square(size));
  for (final size in _macSizes) {
    out['$_macSet/app_icon_$size.png'] = _pngRgba(
      size,
      _macRounded(source, size),
    );
  }
  out[_windowsIco] = File(_sourceIco).readAsBytesSync();
  return out;
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Image RGB 8 bits, trois octets par pixel.
typedef _Image = ({int width, int height, Uint8List rgb});

/// Décode un PNG 8 bits, non entrelacé, RGB ou RGBA (alpha ignoré).
_Image _decodePng(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) _fail('PNG attendu : $_sourcePng');
  }
  final data = ByteData.sublistView(bytes);
  var offset = 8;
  var width = 0;
  var height = 0;
  var channels = 0;
  final idat = BytesBuilder();
  while (offset < bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    final body = offset + 8;
    if (type == 'IHDR') {
      width = data.getUint32(body);
      height = data.getUint32(body + 4);
      final depth = bytes[body + 8];
      final colorType = bytes[body + 9];
      final interlace = bytes[body + 12];
      if (depth != 8 || interlace != 0 || (colorType != 2 && colorType != 6)) {
        _fail('PNG RGB ou RGBA 8 bits non entrelacé attendu.');
      }
      channels = colorType == 2 ? 3 : 4;
    } else if (type == 'IDAT') {
      idat.add(bytes.sublist(body, body + length));
    }
    offset = body + length + 4;
  }
  if (width != height) _fail('Une icône source carrée est attendue.');
  final raw = ZLibCodec().decode(idat.toBytes());
  final stride = width * channels;
  final rgb = Uint8List(width * height * 3);
  var previous = Uint8List(stride);
  for (var y = 0; y < height; y++) {
    final start = y * (stride + 1);
    final filter = raw[start];
    final line = Uint8List.fromList(raw.sublist(start + 1, start + 1 + stride));
    for (var i = 0; i < stride; i++) {
      final a = i >= channels ? line[i - channels] : 0;
      final b = previous[i];
      final c = i >= channels ? previous[i - channels] : 0;
      final predicted = switch (filter) {
        0 => 0,
        1 => a,
        2 => b,
        3 => (a + b) ~/ 2,
        4 => _paeth(a, b, c),
        _ => _fail('Filtre PNG inconnu : $filter'),
      };
      line[i] = (line[i] + predicted) & 255;
    }
    for (var x = 0; x < width; x++) {
      for (var k = 0; k < 3; k++) {
        rgb[(y * width + x) * 3 + k] = line[x * channels + k];
      }
    }
    previous = line;
  }
  return (width: width, height: height, rgb: rgb);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

/// Réduit [source] à [size] px par moyenne de surface (poids fractionnaires),
/// en deux passes séparables. Retourne `size * size * 3` octets.
Uint8List _resize(_Image source, int size) {
  final w = source.width;
  // Passe horizontale : w -> size colonnes, sur chaque ligne source.
  final columns = _weights(w, size, w / size);
  final temp = Float64List(size * source.height * 3);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < size; x++) {
      for (var k = 0; k < 3; k++) {
        var sum = 0.0;
        for (final (index, weight) in columns[x]) {
          sum += source.rgb[(y * w + index) * 3 + k] * weight;
        }
        temp[(y * size + x) * 3 + k] = sum;
      }
    }
  }
  // Passe verticale : height -> size lignes.
  final rows = _weights(source.height, size, source.height / size);
  final out = Uint8List(size * size * 3);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      for (var k = 0; k < 3; k++) {
        var sum = 0.0;
        for (final (index, weight) in rows[y]) {
          sum += temp[(index * size + x) * 3 + k] * weight;
        }
        out[(y * size + x) * 3 + k] = sum.round().clamp(0, 255);
      }
    }
  }
  return out;
}

/// Pour chaque case de sortie, les cases source recouvertes et leur poids
/// (somme égale à 1).
List<List<(int, double)>> _weights(int sourceLength, int size, double ratio) {
  return [
    for (var i = 0; i < size; i++)
      [
        for (
          var s = (i * ratio).floor();
          s < math.min(sourceLength, ((i + 1) * ratio).ceil());
          s++
        )
          (
            s,
            (math.min(s + 1, (i + 1) * ratio) - math.max(s, i * ratio)) / ratio,
          ),
      ],
  ];
}

/// Version macOS : l'image à 80 % de la toile, aux coins arrondis, sur fond
/// transparent. Retourne `size * size * 4` octets (RGBA).
Uint8List _macRounded(_Image source, int size) {
  final content = size * _macContent;
  final inner = _resize(source, content.round().clamp(1, size));
  final innerSize = content.round().clamp(1, size);
  final margin = (size - innerSize) / 2;
  final radius = innerSize * _macRadius;
  final out = Uint8List(size * size * 4);
  const n = _supersampling * _supersampling;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var covered = 0;
      for (var sy = 0; sy < _supersampling; sy++) {
        for (var sx = 0; sx < _supersampling; sx++) {
          final px = x + (sx + 0.5) / _supersampling - margin;
          final py = y + (sy + 0.5) / _supersampling - margin;
          if (_insideRounded(px, py, innerSize.toDouble(), radius)) covered++;
        }
      }
      final ix = (x - margin).floor().clamp(0, innerSize - 1);
      final iy = (y - margin).floor().clamp(0, innerSize - 1);
      final o = (y * size + x) * 4;
      for (var k = 0; k < 3; k++) {
        out[o + k] = inner[(iy * innerSize + ix) * 3 + k];
      }
      out[o + 3] = (covered * 255 / n).round();
    }
  }
  return out;
}

bool _insideRounded(double x, double y, double side, double radius) {
  if (x < 0 || y < 0 || x > side || y > side) return false;
  final dx = math.max(radius - x, x - (side - radius));
  final dy = math.max(radius - y, y - (side - radius));
  if (dx <= 0 || dy <= 0) return true;
  return dx * dx + dy * dy <= radius * radius;
}

/// PNG RGB carré (fond plein : pas de transparence, donc pas de coins noirs
/// une fois masqué par le système).
Uint8List _png(int size, Uint8List rgb) =>
    _encode(size, rgb, channels: 3, colorType: 2);

Uint8List _pngRgba(int size, Uint8List rgba) =>
    _encode(size, rgba, channels: 4, colorType: 6);

Uint8List _encode(
  int size,
  Uint8List pixels, {
  required int channels,
  required int colorType,
}) {
  final stride = size * channels;
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw
      ..addByte(0) // filtre « aucun »
      ..add(pixels.sublist(y * stride, (y + 1) * stride));
  }
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

  chunk('IHDR', [..._u32(size), ..._u32(size), 8, colorType, 0, 0, 0]);
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
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
