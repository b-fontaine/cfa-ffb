/// Ton d'un minuteur : neutre, attention sous une minute, dépassé sous zéro.
///
/// Source unique du seuil, partagée par le composant `TimerChip` et par le
/// guide en mode « Mener » (seuils de vibration).
enum TimerTone { neutral, attention, overdue }

/// Durée sous laquelle le minuteur passe à `attention`.
const Duration timerAttentionThreshold = Duration(minutes: 1);

/// Ton du minuteur pour le temps [remaining] (fonction pure, seuils bornés :
/// `attention` de 0 inclus à 1 min exclue, `overdue` strictement sous 0).
TimerTone timerToneFor(Duration remaining) {
  if (remaining.isNegative) return TimerTone.overdue;
  if (remaining < timerAttentionThreshold) return TimerTone.attention;
  return TimerTone.neutral;
}
