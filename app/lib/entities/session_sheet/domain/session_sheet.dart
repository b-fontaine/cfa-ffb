import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_initiation.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall_slot.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_source.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theme.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_sheet.freezed.dart';

Never _invalid(String detail) =>
    throw InvariantViolation(InvariantCode.invalidSheet, detail);

bool _unique(Iterable<String> ids) => ids.toSet().length == ids.length;

/// Une séance du catalogue : une partie d'une technique, pour les deux
/// publics, en lecture seule.
///
/// Le minutage n'est jamais porté : il est calculé (`sheetTiming`) à partir
/// des poids par public. `previous` est la séance d'ordre `order - 1`
/// (`null` pour la première) ; une partie `k > 1` suit la partie `k - 1`.
/// `recallSlot` (ADR 0011) existe si et seulement si la séance en a une
/// précédente.
@freezed
abstract class SessionSheet with _$SessionSheet {
  factory SessionSheet({
    required SheetId id,
    required int order,
    required String technique,
    required int part,
    required String title,
    required List<int> technicalSheets,
    required String catalogueBlock,
    required String notion,
    required SheetTheme theme,
    required SheetRecall recall,
    required List<SheetTheorySection> theorySections,
    required List<Illustration> illustrations,
    required List<SheetExercise> exercises,
    required SheetGame game,
    required List<String> reviewPrompts,
    required List<SheetSourceRef> sources,
    SheetId? previous,
    SheetRecallSlot? recallSlot,
    @Default(<SheetInitiation>[]) List<SheetInitiation> initiation,
    @Default(<String>[]) List<String> uncertainties,
  }) = _SessionSheet;

  SessionSheet._() {
    if (order < 1 || part < 1) _invalid('order et part : entiers >= 1');
    if (id.value != '$technique-$part') {
      _invalid('id attendu : $technique-$part, trouvé : $id');
    }
    if (title.trim().isEmpty || notion.trim().isEmpty) {
      _invalid('title et notion : textes non vides');
    }
    if ((previous == null) != (order == 1)) {
      _invalid('previous : nul si et seulement si order vaut 1');
    }
    if ((recallSlot == null) != (order == 1)) {
      _invalid('recallSlot : absent si et seulement si order vaut 1');
    }
    if (theorySections.isEmpty ||
        exercises.isEmpty ||
        reviewPrompts.isEmpty ||
        sources.isEmpty) {
      _invalid('théorie, exercices, bilan et sources : non vides');
    }
    _checkIllustrations();
    _checkIds();
    _checkExercises();
    _checkGame();
    _checkRecall();
    _checkAudiences();
  }

  void _checkIllustrations() {
    final ids = illustrations.map((i) => i.id).toList();
    if (!_unique(ids)) _invalid('illustrations : identifiants en double');
    for (final i in illustrations) {
      if (i.caption.trim().isEmpty || i.alt.trim().isEmpty) {
        _invalid('illustration ${i.id} : légende et texte alternatif requis');
      }
    }
    final cited = [
      for (final s in theorySections) ...s.illustrationIds,
      for (final i in initiation)
        if (i.illustrationId != null) i.illustrationId!,
      if (game.setupIllustrationId != null) game.setupIllustrationId!,
    ];
    for (final id in cited) {
      if (!ids.contains(id)) _invalid('illustration citée absente : $id');
    }
  }

  void _checkIds() {
    if (!_unique(theorySections.map((s) => s.id))) {
      _invalid('théorie : identifiants en double');
    }
    if (!_unique(initiation.map((i) => i.id))) {
      _invalid('initiation : identifiants en double');
    }
    if (!_unique(exercises.map((e) => e.id))) {
      _invalid('exercices : identifiants en double');
    }
  }

  void _checkExercises() {
    final numbers = exercises.map((e) => e.ref.number).toList();
    if (numbers.toSet().length != numbers.length) {
      _invalid('exercices : numéros du catalogue en double');
    }
    final slot = recallSlot;
    if (slot != null && (slot.passes < 1 || slot.passes > 2)) {
      _invalid('créneau de rappel : passes doit valoir 1 ou 2');
    }
    for (final e in exercises) {
      if (e.ref.blockId != catalogueBlock) {
        _invalid('exercice ${e.id} : bloc ${e.ref.blockId} != $catalogueBlock');
      }
      if (e.passes < 1 || e.passes > 2) {
        _invalid('exercice ${e.id} : passes doit valoir 1 ou 2');
      }
    }
  }

  void _checkGame() {
    if (game.adapted && !game.src.isProposal) {
      _invalid('jeu adapté : src Prop obligatoire');
    }
    final link = game.link;
    if (order == 1) {
      if (link != null) _invalid('jeu : pas de lien à la première séance');
    } else if (link == null ||
        link.notionOf != previous ||
        link.rule.trim().isEmpty ||
        link.note.trim().isEmpty) {
      _invalid('jeu : lien vers la séance précédente obligatoire');
    }
  }

  void _checkRecall() {
    final reuse = recall.reuse;
    if (reuse != null && reuse.sheet != previous) {
      _invalid('rappel : la réutilisation porte sur la séance précédente');
    }
  }

  void _checkAudiences() {
    for (final audience in Audience.values) {
      if (!theorySections.any((s) => s.weight.isShownFor(audience)) ||
          !exercises.any((e) => e.weight.isShownFor(audience)) ||
          !game.weight.isShownFor(audience)) {
        _invalid('${audience.name} : théorie, exercice et jeu affichés requis');
      }
      final slot = recallSlot;
      if (slot != null && !slot.weight.isShownFor(audience)) {
        _invalid('${audience.name} : créneau de rappel affiché requis');
      }
    }
  }
}
