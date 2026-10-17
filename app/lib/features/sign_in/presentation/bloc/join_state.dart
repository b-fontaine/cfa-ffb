import 'package:freezed_annotation/freezed_annotation.dart';

part 'join_state.freezed.dart';

/// Pourquoi on ne rejoint pas encore le club.
enum JoinFailureCode {
  /// Le code saisi n'a pas la forme d'un code.
  invalidCode,

  /// Aucune invitation pour ce code (jamais créée, ou révoquée).
  notFound,
  expired,
  used,

  /// Le serveur refuse (déjà membre de ce club, invitation consommée
  /// entre-temps).
  refused,

  /// Le nom est vide ou trop long.
  name,

  /// Réseau ou service injoignable.
  unavailable,
}

/// Avancement de l'écran « Rejoindre un club ».
enum JoinStatus { editing, submitting, done, failed }

@freezed
abstract class JoinState with _$JoinState {
  const factory JoinState({
    @Default(JoinStatus.editing) JoinStatus status,
    JoinFailureCode? failure,
  }) = _JoinState;
}
