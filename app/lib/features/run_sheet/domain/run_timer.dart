/// Temps restant d'une phase de [plannedMinutes] minutes après
/// [elapsedSeconds] secondes écoulées (négatif au dépassement).
Duration runTimerRemaining({
  required int plannedMinutes,
  required int elapsedSeconds,
}) => Duration(minutes: plannedMinutes) - Duration(seconds: elapsedSeconds);
