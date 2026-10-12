import 'package:flutter/material.dart';

/// Couleurs de statut absentes de `ColorScheme` : succès et attention.
///
/// Valeurs **proposées**, vérifiées par le test de contraste.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.attention,
    required this.onAttention,
  });

  static const light = StatusColors(
    success: Color(0xFF1B6B3A),
    onSuccess: Color(0xFFFFFFFF),
    attention: Color(0xFFFFF0C2),
    onAttention: Color(0xFF3D2E00),
  );

  static const dark = StatusColors(
    success: Color(0xFF8FD9A8),
    onSuccess: Color(0xFF00391A),
    attention: Color(0xFF4D3B00),
    onAttention: Color(0xFFFFE9A8),
  );

  final Color success;
  final Color onSuccess;

  /// Fond d'une alerte « attention » (conteneur ambré).
  final Color attention;
  final Color onAttention;

  @override
  StatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? attention,
    Color? onAttention,
  }) => StatusColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    attention: attention ?? this.attention,
    onAttention: onAttention ?? this.onAttention,
  );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      onAttention: Color.lerp(onAttention, other.onAttention, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatusColors &&
      other.success == success &&
      other.onSuccess == onSuccess &&
      other.attention == attention &&
      other.onAttention == onAttention;

  @override
  int get hashCode => Object.hash(success, onSuccess, attention, onAttention);
}
