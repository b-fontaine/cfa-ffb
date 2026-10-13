import 'package:flutter/material.dart';

/// Couleurs de la table de Blackball et de la queue de billard.
///
/// Valeurs **proposées** (non publiées par la FFB) : elles évoquent les
/// schémas des fiches fédérales (rails gris bois, poches noires, losanges
/// blancs). Le tapis lui-même reste `BallColors.cloth`.
///
/// Le trait de contour de la queue (`cueButt`) et les repères de la table
/// atteignent 3:1 contre ce qui les porte (voir `table_colors_test.dart`).
@immutable
class TableColors extends ThemeExtension<TableColors> {
  const TableColors({
    required this.rail,
    required this.cushion,
    required this.pocket,
    required this.diamond,
    required this.headString,
    required this.grid,
    required this.cueWood,
    required this.cueButt,
    required this.cueFerrule,
    required this.cueTip,
    required this.chalk,
  });

  static const light = TableColors(
    rail: Color(0xFF8F8A82),
    cushion: Color(0xFF245572),
    pocket: Color(0xFF0D0D0D),
    diamond: Color(0xFFFFFFFF),
    headString: Color(0xFF0B2F40),
    grid: Color(0xFF3F7596),
    cueWood: Color(0xFFE8C98F),
    cueButt: Color(0xFF3B2412),
    cueFerrule: Color(0xFFF6F1E4),
    cueTip: Color(0xFF2B4A63),
    chalk: Color(0xFF1B55B5),
  );

  static const dark = TableColors(
    rail: Color(0xFF6F6A63),
    cushion: Color(0xFF8CC1DD),
    pocket: Color(0xFF000000),
    diamond: Color(0xFFF2F2F2),
    headString: Color(0xFFE6EEF3),
    grid: Color(0xFF8CC1DD),
    cueWood: Color(0xFFE8C98F),
    cueButt: Color(0xFFF1DDB5),
    cueFerrule: Color(0xFFF6F1E4),
    cueTip: Color(0xFF9DB8CC),
    chalk: Color(0xFF1B55B5),
  );

  /// Rails (cadre) en gris bois, comme sur les schémas du PDF.
  final Color rail;

  /// Bande intérieure (le bord sur lequel rebondissent les billes).
  final Color cushion;

  /// Poches.
  final Color pocket;

  /// Losanges (diamants) posés sur les rails.
  final Color diamond;

  /// Ligne de départ (x = 2).
  final Color headString;

  /// Grille pointillée 8 × 4.
  final Color grid;

  /// Fût de la queue (bois clair).
  final Color cueWood;

  /// Talon de la queue ; sert aussi de contour sur le tapis.
  final Color cueButt;

  /// Virole (anneau entre le fût et le procédé).
  final Color cueFerrule;

  /// Procédé (cuir au bout de la queue).
  final Color cueTip;

  /// Craie bleue : point d'impact du procédé sur la blanche.
  final Color chalk;

  @override
  TableColors copyWith({
    Color? rail,
    Color? cushion,
    Color? pocket,
    Color? diamond,
    Color? headString,
    Color? grid,
    Color? cueWood,
    Color? cueButt,
    Color? cueFerrule,
    Color? cueTip,
    Color? chalk,
  }) => TableColors(
    rail: rail ?? this.rail,
    cushion: cushion ?? this.cushion,
    pocket: pocket ?? this.pocket,
    diamond: diamond ?? this.diamond,
    headString: headString ?? this.headString,
    grid: grid ?? this.grid,
    cueWood: cueWood ?? this.cueWood,
    cueButt: cueButt ?? this.cueButt,
    cueFerrule: cueFerrule ?? this.cueFerrule,
    cueTip: cueTip ?? this.cueTip,
    chalk: chalk ?? this.chalk,
  );

  @override
  TableColors lerp(ThemeExtension<TableColors>? other, double t) {
    if (other is! TableColors) return this;
    return TableColors(
      rail: Color.lerp(rail, other.rail, t)!,
      cushion: Color.lerp(cushion, other.cushion, t)!,
      pocket: Color.lerp(pocket, other.pocket, t)!,
      diamond: Color.lerp(diamond, other.diamond, t)!,
      headString: Color.lerp(headString, other.headString, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      cueWood: Color.lerp(cueWood, other.cueWood, t)!,
      cueButt: Color.lerp(cueButt, other.cueButt, t)!,
      cueFerrule: Color.lerp(cueFerrule, other.cueFerrule, t)!,
      cueTip: Color.lerp(cueTip, other.cueTip, t)!,
      chalk: Color.lerp(chalk, other.chalk, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TableColors &&
      other.rail == rail &&
      other.cushion == cushion &&
      other.pocket == pocket &&
      other.diamond == diamond &&
      other.headString == headString &&
      other.grid == grid &&
      other.cueWood == cueWood &&
      other.cueButt == cueButt &&
      other.cueFerrule == cueFerrule &&
      other.cueTip == cueTip &&
      other.chalk == chalk;

  @override
  int get hashCode => Object.hash(
    rail,
    cushion,
    pocket,
    diamond,
    headString,
    grid,
    cueWood,
    cueButt,
    cueFerrule,
    cueTip,
    chalk,
  );
}
