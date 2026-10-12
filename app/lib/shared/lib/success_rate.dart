import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'success_rate.freezed.dart';

/// Taux de réussite requis d'un exercice : `successes` billes sur `attempts`.
@freezed
abstract class SuccessRate with _$SuccessRate {
  factory SuccessRate({required int successes, required int attempts}) =
      _SuccessRate;

  SuccessRate._() {
    if (successes < 1 || successes > attempts || attempts > maxAttempts) {
      throw const InvariantViolation(InvariantCode.successRateOutOfRange);
    }
  }

  /// Borne haute de l'axe des fiches résultats (0 à 16) `[S]`.
  static const maxAttempts = 16;

  /// Vrai si [total] est comparable au taux de la fiche : au moins les
  /// tentatives de la fiche `[S]`. En dessous, le taux n'est plus celui de la
  /// source (un seul passage « 1 sur 1 » ne prouve rien) `[Prop]`.
  bool acceptsTotal(int total) => total >= attempts;

  /// Vrai si [potted] sur [total] atteint le taux requis. Le total doit
  /// couvrir les tentatives de la fiche ([acceptsTotal]) ; au-delà, la
  /// comparaison de proportions est exacte `[Prop]`.
  bool isReachedBy({required int potted, required int total}) =>
      acceptsTotal(total) && potted * attempts >= successes * total;

  /// Résultat rapporté au taux requis : 1 = taux atteint, > 1 = dépassé.
  double relativeScore({required int potted, required int total}) =>
      (potted * attempts) / (successes * total);
}
