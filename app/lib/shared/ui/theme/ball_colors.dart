import 'package:flutter/material.dart';

/// Couleurs sémantiques des billes de Blackball et du tapis.
///
/// Valeurs **proposées** (non publiées par la FFB, à valider visuellement).
/// Une bille n'est jamais identifiée par sa couleur seule : voir `BallChip`.
@immutable
class BallColors extends ThemeExtension<BallColors> {
  const BallColors({
    required this.red,
    required this.onRed,
    required this.yellow,
    required this.onYellow,
    required this.black,
    required this.onBlack,
    required this.white,
    required this.onWhite,
    required this.cloth,
    required this.onCloth,
  });

  static const light = BallColors(
    red: Color(0xFFD4101E),
    onRed: Color(0xFFFFFFFF),
    yellow: Color(0xFFF2C200),
    onYellow: Color(0xFF1A1400),
    black: Color(0xFF111111),
    onBlack: Color(0xFFFFFFFF),
    white: Color(0xFFFFFFFF),
    onWhite: Color(0xFF10161D),
    cloth: Color(0xFF7FB0CF),
    onCloth: Color(0xFF0B2F40),
  );

  static const dark = BallColors(
    red: Color(0xFFD4101E),
    onRed: Color(0xFFFFFFFF),
    yellow: Color(0xFFF2C200),
    onYellow: Color(0xFF1A1400),
    black: Color(0xFF111111),
    onBlack: Color(0xFFFFFFFF),
    white: Color(0xFFFFFFFF),
    onWhite: Color(0xFF10161D),
    cloth: Color(0xFF2D6A8A),
    onCloth: Color(0xFFFFFFFF),
  );

  final Color red;
  final Color onRed;
  final Color yellow;
  final Color onYellow;
  final Color black;
  final Color onBlack;
  final Color white;
  final Color onWhite;

  /// Bleu poudre du tapis (règlement Blackball FFB), teinte approchée.
  final Color cloth;
  final Color onCloth;

  @override
  BallColors copyWith({
    Color? red,
    Color? onRed,
    Color? yellow,
    Color? onYellow,
    Color? black,
    Color? onBlack,
    Color? white,
    Color? onWhite,
    Color? cloth,
    Color? onCloth,
  }) => BallColors(
    red: red ?? this.red,
    onRed: onRed ?? this.onRed,
    yellow: yellow ?? this.yellow,
    onYellow: onYellow ?? this.onYellow,
    black: black ?? this.black,
    onBlack: onBlack ?? this.onBlack,
    white: white ?? this.white,
    onWhite: onWhite ?? this.onWhite,
    cloth: cloth ?? this.cloth,
    onCloth: onCloth ?? this.onCloth,
  );

  @override
  BallColors lerp(ThemeExtension<BallColors>? other, double t) {
    if (other is! BallColors) return this;
    return BallColors(
      red: Color.lerp(red, other.red, t)!,
      onRed: Color.lerp(onRed, other.onRed, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      onYellow: Color.lerp(onYellow, other.onYellow, t)!,
      black: Color.lerp(black, other.black, t)!,
      onBlack: Color.lerp(onBlack, other.onBlack, t)!,
      white: Color.lerp(white, other.white, t)!,
      onWhite: Color.lerp(onWhite, other.onWhite, t)!,
      cloth: Color.lerp(cloth, other.cloth, t)!,
      onCloth: Color.lerp(onCloth, other.onCloth, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BallColors &&
      other.red == red &&
      other.onRed == onRed &&
      other.yellow == yellow &&
      other.onYellow == onYellow &&
      other.black == black &&
      other.onBlack == onBlack &&
      other.white == white &&
      other.onWhite == onWhite &&
      other.cloth == cloth &&
      other.onCloth == onCloth;

  @override
  int get hashCode => Object.hash(
    red,
    onRed,
    yellow,
    onYellow,
    black,
    onBlack,
    white,
    onWhite,
    cloth,
    onCloth,
  );
}
