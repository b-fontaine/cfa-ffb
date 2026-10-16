import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';

/// Libellé d'un motif de relecture. Les motifs qui comptent disent ce qui est
/// « à valider » ; les motifs seulement signalés (théorie, règle de lien)
/// disent que c'est une proposition, sans compter dans le « n ».
String reviewReasonLabel(AppLocalizations l10n, ReviewReason reason) =>
    switch (reason) {
      ReviewReason.game => l10n.catalogueReasonGame,
      ReviewReason.exercise => l10n.catalogueReasonExercise,
      ReviewReason.initiation => l10n.catalogueReasonInitiation,
      ReviewReason.recall => l10n.catalogueReasonRecall,
      ReviewReason.gameLink => l10n.catalogueMinorGameLink,
      ReviewReason.theory => l10n.catalogueMinorTheory,
    };
