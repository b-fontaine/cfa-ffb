/// Public visé par une séance ; détermine sa durée.
enum Audience {
  children(Duration(minutes: 90)),
  adults(Duration(minutes: 120));

  Audience(this.sessionDuration);

  /// Durée standard d'une séance pour ce public.
  final Duration sessionDuration;
}
