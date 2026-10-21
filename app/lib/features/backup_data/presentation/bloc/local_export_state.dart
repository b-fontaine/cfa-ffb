part of 'local_export_cubit.dart';

enum LocalExportStatus {
  /// Lecture des données de l'appareil en cours.
  loading,

  /// Fichier prêt : [LocalExportState.summary] dit ce qu'il contient, avant
  /// tout enregistrement.
  ready,

  /// Enregistré (jamais pour un fichier vide).
  saved,

  /// L'animateur a annulé le choix de l'emplacement : rien n'est enregistré.
  cancelled,

  /// Base écrite par une version plus récente : export refusé.
  newerSchema,

  /// Lecture impossible : jamais présentée comme « vide ».
  unreadable,

  /// Le fichier prêt n'a pas pu être enregistré (disque, navigateur).
  saveFailed,
}

/// Ce que l'écran d'export sait du fichier en préparation.
@freezed
abstract class LocalExportState with _$LocalExportState {
  const factory LocalExportState({
    @Default(LocalExportStatus.loading) LocalExportStatus status,

    /// Contenu du fichier prêt (ou enregistré).
    ImportSummary? summary,

    /// La base venait d'une version plus ancienne (mise à niveau à
    /// l'ouverture).
    @Default(false) bool migrated,
  }) = _LocalExportState;

  const LocalExportState._();

  /// Un fichier existe, il a du contenu et il n'est pas encore enregistré.
  bool get canSave =>
      (status == LocalExportStatus.ready ||
          status == LocalExportStatus.cancelled) &&
      summary != null &&
      !summary!.holdsNothing;

  /// Le fichier prêt ne contient rien : message d'avertissement, pas
  /// d'enregistrement.
  bool get empty =>
      (status == LocalExportStatus.ready ||
          status == LocalExportStatus.cancelled) &&
      (summary?.holdsNothing ?? false);
}
