import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/audience.dart';

/// Ce qui, dans une séance, est une proposition `[Prop]` à valider.
enum ReviewReason {
  /// Jeu adapté, sans source, ou dont la fiche de séance est `[Prop]`.
  game(counts: true),

  /// Exercice d'un bloc `[Prop]`.
  exercise(counts: true),

  /// Initiation `[Prop]`.
  initiation(counts: true),

  /// Rappel `[Prop]`.
  recall(counts: true),

  /// Jeu sourcé `[S]` auquel la séance ajoute une règle de lien `[Prop]` :
  /// signalé dans la liste, mais le jeu lui-même est fédéral.
  gameLink(counts: false),

  /// Section de théorie `[Prop]` montrée aussi aux adultes (hors glose) :
  /// signalée dans la liste, mais elle ne déclenche pas l'indicateur.
  theory(counts: false);

  ReviewReason({required this.counts});

  /// Vrai si ce motif suffit à rendre la séance « à valider » (indicateur et
  /// filtre) ; faux s'il est seulement signalé.
  final bool counts;
}

/// Les motifs `[Prop]` présents dans [sheet] (FORMAT des séances § 5.3),
/// vides si elle est entièrement sourcée.
///
/// Le thème, les défis, la variante, les poids et les minutes sont `[Prop]`
/// par définition : ils sont badgés à l'écran mais ne sont pas des motifs. Une
/// **glose** (section de théorie `[Prop]` réservée aux enfants, qui explique
/// un mot) n'en est pas un non plus. La règle de lien n'est comptée que pour
/// un jeu sourcé : un jeu adapté est déjà à valider en entier. Fonction pure :
/// rien n'est stocké.
Set<ReviewReason> reviewReasonsOf(SessionSheet sheet) {
  final game = sheet.game;
  final gameToReview =
      game.adapted || game.sourceGame == null || game.src.isProposal;
  return {
    if (gameToReview) ReviewReason.game,
    if (sheet.exercises.any((e) => e.src.isProposal)) ReviewReason.exercise,
    if (sheet.initiation.any((i) => i.src.isProposal)) ReviewReason.initiation,
    if (sheet.recall.src.isProposal) ReviewReason.recall,
    if (!gameToReview && game.link != null) ReviewReason.gameLink,
    if (sheet.theorySections.any(
      (s) => s.src.isProposal && s.weight.isShownFor(Audience.adults),
    ))
      ReviewReason.theory,
  };
}

/// Vrai si [sheet] est « à valider » : un motif qui compte (jeu, exercice,
/// initiation, rappel) est présent. Sur les 28 séances réelles, la théorie
/// `[Prop]` (24) et la règle de lien (16 sur des jeux sourcés) sont si
/// répandues qu'elles videraient l'indicateur de son sens : elles sont
/// signalées par `reviewReasonsOf` sans le déclencher.
bool needsReview(SessionSheet sheet) =>
    reviewReasonsOf(sheet).any((reason) => reason.counts);

/// Vrai si le jeu de [sheet] est à valider (adapté, sans source ou `[Prop]`).
bool gameNeedsReview(SessionSheet sheet) =>
    reviewReasonsOf(sheet).contains(ReviewReason.game);
