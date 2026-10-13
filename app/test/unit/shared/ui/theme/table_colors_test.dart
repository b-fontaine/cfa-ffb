import 'package:billard_cfa/shared/ui/theme/app_color_schemes.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final variants = <String, (TableColors, BallColors, ColorScheme)>{
    'light': (TableColors.light, BallColors.light, AppColorSchemes.light),
    'dark': (TableColors.dark, BallColors.dark, AppColorSchemes.dark),
  };

  for (final entry in variants.entries) {
    final (table, balls, scheme) = entry.value;

    test('${entry.key}: markings stand out from what they sit on (3:1)', () {
      final pairs = <String, double>{
        'diamond on rail': _contrast(table.diamond, table.rail),
        'pocket on rail': _contrast(table.pocket, table.rail),
        'head string on cloth': _contrast(table.headString, balls.cloth),
        'cushion on cloth': _contrast(table.cushion, balls.cloth),
        'cue outline on cloth': _contrast(table.cueButt, balls.cloth),
        'cue outline on surface': _contrast(table.cueButt, scheme.surface),
        'chalk on white ball': _contrast(table.chalk, balls.white),
      };

      final failures = <String>[
        for (final e in pairs.entries)
          if (e.value < 3) '${e.key} = ${e.value.toStringAsFixed(2)}',
      ];
      expect(failures, isEmpty);
    });

    test(
      '${entry.key}: the dotted grid stays visible on the cloth (1.5:1)',
      () {
        expect(_contrast(table.grid, balls.cloth), greaterThanOrEqualTo(1.5));
      },
    );
  }

  test('theme registers the table colours for both modes', () {
    expect(AppTheme.light().extension<TableColors>(), TableColors.light);
    expect(AppTheme.dark().extension<TableColors>(), TableColors.dark);
  });

  // Chaque champ, avec de quoi le lire et le remplacer. Une couleur distincte
  // par champ : un champ oublié dans copyWith, lerp, == ou hashCode se voit.
  final fields =
      <
        (
          String,
          Color Function(TableColors),
          TableColors Function(TableColors, Color),
        )
      >[
        ('rail', (t) => t.rail, (t, c) => t.copyWith(rail: c)),
        ('cushion', (t) => t.cushion, (t, c) => t.copyWith(cushion: c)),
        ('pocket', (t) => t.pocket, (t, c) => t.copyWith(pocket: c)),
        ('diamond', (t) => t.diamond, (t, c) => t.copyWith(diamond: c)),
        (
          'headString',
          (t) => t.headString,
          (t, c) => t.copyWith(headString: c),
        ),
        ('grid', (t) => t.grid, (t, c) => t.copyWith(grid: c)),
        ('cueWood', (t) => t.cueWood, (t, c) => t.copyWith(cueWood: c)),
        ('cueButt', (t) => t.cueButt, (t, c) => t.copyWith(cueButt: c)),
        (
          'cueFerrule',
          (t) => t.cueFerrule,
          (t, c) => t.copyWith(cueFerrule: c),
        ),
        ('cueTip', (t) => t.cueTip, (t, c) => t.copyWith(cueTip: c)),
        ('chalk', (t) => t.chalk, (t, c) => t.copyWith(chalk: c)),
      ];

  test('copyWith replaces only the requested field, for every field', () {
    const other = Color(0xFF123456);
    for (final (name, read, replace) in fields) {
      final copy = replace(TableColors.light, other);
      expect(read(copy), other, reason: name);
      expect(copy, isNot(TableColors.light), reason: name);
      expect(copy.hashCode, isNot(TableColors.light.hashCode), reason: name);
      for (final (otherName, otherRead, _) in fields) {
        if (otherName == name) continue;
        expect(
          otherRead(copy),
          otherRead(TableColors.light),
          reason: '$name must not change $otherName',
        );
      }
    }
  });

  test('copyWith without argument is an equal copy', () {
    final copy = TableColors.light.copyWith();
    expect(copy, TableColors.light);
    expect(identical(copy, TableColors.light), isFalse);
  });

  test('lerp interpolates every field', () {
    // Une cible distincte de l'origine sur chaque champ.
    var target = TableColors.light;
    for (var i = 0; i < fields.length; i++) {
      target = fields[i].$3(target, Color(0xFF000000 + 0x101010 * (i + 1)));
    }
    final mid = TableColors.light.lerp(target, 0.25);
    for (final (name, read, _) in fields) {
      expect(
        read(mid),
        Color.lerp(read(TableColors.light), read(target), 0.25),
        reason: name,
      );
    }
    expect(TableColors.light.lerp(null, 0.5), TableColors.light);
    expect(TableColors.light.lerp(TableColors.dark, 0), TableColors.light);
    expect(TableColors.light.lerp(TableColors.dark, 1), TableColors.dark);
  });

  test('equal values share a hash code', () {
    expect(TableColors.light.copyWith().hashCode, TableColors.light.hashCode);
    expect(TableColors.light, isNot(TableColors.dark));
  });
}
