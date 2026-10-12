part of 'audience_change_bloc.dart';

@freezed
sealed class AudienceChangeEvent with _$AudienceChangeEvent {
  const factory AudienceChangeEvent.requested({
    required StudentId studentId,
    required Audience audience,

    /// Nom (localisé) du groupe créé si le public n'en a pas encore.
    required String groupName,
  }) = AudienceChangeRequested;
}
