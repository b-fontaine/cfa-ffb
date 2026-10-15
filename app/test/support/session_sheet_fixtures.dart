import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_initiation.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall_slot.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_source.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theme.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';

/// Illustration de contact valide, identifiant [id].
Illustration contactIllustration(String id) => Illustration.contact(
  id: id,
  caption: 'Légende $id',
  alt: 'Texte alternatif $id',
  fraction: ContactFraction.half,
  tipPoint: TipPoint.center,
);

SheetTheorySection theorySection(
  String id, {
  AudienceWeight? weight,
  Provenance src = Provenance.s,
  List<String> illustrations = const [],
}) => SheetTheorySection(
  id: id,
  title: 'Section $id',
  weight: weight ?? AudienceWeight(children: 1, adults: 1),
  body: const ['Une phrase.'],
  keyPoint: 'À retenir.',
  illustrationIds: illustrations,
  src: src,
);

SheetExercise sheetExercise(
  String id,
  int number, {
  String block = 'demi-bille',
  AudienceWeight? weight,
  Provenance src = Provenance.s,
  int passes = 1,
}) => SheetExercise(
  id: id,
  ref: ExerciseRef(blockId: block, number: number),
  diagramId: 'entrainement-p05-e$number',
  title: 'Exercice $id',
  weight: weight ?? AudienceWeight(children: 1, adults: 1),
  setup: 'Mise en place.',
  instruction: 'Consigne.',
  expected: 'Attendu.',
  playful: const SheetPlayful(hook: 'Accroche.', challenge: 'Défi.'),
  passes: passes,
  src: src,
);

SheetGame sheetGame({
  bool adapted = false,
  int? sourceGame = 7,
  Provenance src = Provenance.s,
  SheetLink? link,
  AudienceWeight? weight,
  String? setupIllustration,
}) => SheetGame(
  title: 'Jeu',
  sourceGame: sourceGame,
  adapted: adapted,
  players: 'Partie à 2',
  rules: const ['Règle.'],
  scoring: 'Score.',
  end: 'Fin.',
  playfulVariant: 'Variante.',
  link: link,
  weight: weight ?? AudienceWeight(children: 1, adults: 1),
  adaptation: const SheetAdaptation(),
  setupIllustrationId: setupIllustration,
  src: src,
);

/// Séance valide : demi-bille, partie 1 (order 9), précédente bille-pleine-2.
///
/// Les arguments remplacent les éléments correspondants ; les valeurs par
/// défaut ne contiennent aucune proposition de contenu.
SessionSheet buildSheet({
  String technique = 'demi-bille',
  int part = 1,
  int order = 9,
  Object? previous = 'bille-pleine-2',
  String block = 'demi-bille',
  SheetRecall? recall,
  List<SheetTheorySection>? theory,
  List<SheetInitiation> initiation = const [],
  List<Illustration>? illustrations,
  List<SheetExercise>? exercises,
  SheetGame? game,
  List<String> review = const ['Question ?'],
  SheetRecallSlot? recallSlot,
}) {
  final prev = previous == null ? null : SheetId(previous as String);
  return SessionSheet(
    id: SheetId('$technique-$part'),
    order: order,
    technique: technique,
    part: part,
    title: 'Quantité $technique',
    technicalSheets: const [5],
    previous: prev,
    recallSlot:
        recallSlot ??
        (prev == null
            ? null
            : SheetRecallSlot(
                weight: AudienceWeight(children: 1, adults: 1),
                passes: 1,
              )),
    catalogueBlock: block,
    notion: 'Viser la tangente.',
    theme: const SheetTheme(name: 'Le partage', pitch: 'Un gâteau.'),
    recall:
        recall ??
        const SheetRecall(
          points: ['Un point.', 'Un autre.'],
          ask: 'Question ?',
          answer: 'Réponse.',
          src: Provenance.s,
        ),
    theorySections: theory ?? [theorySection('t1')],
    initiation: initiation,
    illustrations: illustrations ?? const [],
    exercises: exercises ?? [sheetExercise('e1', 1), sheetExercise('e2', 2)],
    game:
        game ??
        sheetGame(
          link: prev == null
              ? null
              : SheetLink(notionOf: prev, rule: 'Règle.', note: 'Note.'),
        ),
    reviewPrompts: review,
    sources: const [
      SheetSourceRef(
        rank: Provenance.s,
        file: 'Fiches techniques CFA BàP.pdf',
        page: 15,
        note: 'Fiche 5',
      ),
    ],
  );
}

SheetInitiation sheetInitiation(
  String id, {
  Scoring? scoring,
  String? illustration,
  Provenance src = Provenance.s,
}) => SheetInitiation(
  id: id,
  initiationSheet: 7,
  title: 'Initiation $id',
  weight: AudienceWeight(children: 1, adults: 1),
  setup: 'Mise en place.',
  goal: 'Consigne.',
  expected: 'Attendu.',
  scoring: scoring ?? const Scoring.counter(of: 5),
  illustrationId: illustration,
  src: src,
);

/// Catalogue de test : 3 techniques chaînées dont une à 2 parties.
///
/// `posture-1` (exercices d'un bloc `[Prop]`) et `quart-1` (jeu adapté) sont
/// « à valider » ; `demi-bille-1` et `demi-bille-2` ne contiennent aucune
/// proposition de contenu.
List<SessionSheet> catalogueFixture() => [
  buildSheet(
    technique: 'posture',
    order: 1,
    previous: null,
    block: 'posture',
    exercises: [
      sheetExercise('e1', 1, block: 'posture', src: Provenance.prop),
      sheetExercise('e2', 2, block: 'posture', src: Provenance.prop),
    ],
  ),
  buildSheet(order: 2, previous: 'posture-1'),
  buildSheet(
    part: 2,
    order: 3,
    previous: 'demi-bille-1',
    exercises: [sheetExercise('e3', 3), sheetExercise('e4', 4)],
  ),
  buildSheet(
    technique: 'quart',
    order: 4,
    previous: 'demi-bille-2',
    block: 'quart-finesses',
    exercises: [
      sheetExercise('e1', 1, block: 'quart-finesses'),
      sheetExercise('e2', 2, block: 'quart-finesses'),
    ],
    game: sheetGame(
      adapted: true,
      src: Provenance.prop,
      link: SheetLink(
        notionOf: SheetId('demi-bille-2'),
        rule: 'Règle.',
        note: 'Note.',
      ),
    ),
  ),
];

/// Séances du catalogue de test dont les blocs sont ceux du catalogue
/// d'entraînement de test (`a`, `b`, `c`) : `posture-1` (bloc a),
/// `demi-bille-1` et `demi-bille-2` (bloc b).
List<SessionSheet> sheetsOnTestBlocks() => [
  buildSheet(
    technique: 'posture',
    order: 1,
    previous: null,
    block: 'a',
    exercises: [
      sheetExercise('e1', 1, block: 'a'),
      sheetExercise('e2', 2, block: 'a'),
    ],
  ),
  buildSheet(
    order: 2,
    previous: 'posture-1',
    block: 'b',
    exercises: [
      sheetExercise('e1', 1, block: 'b'),
      sheetExercise('e2', 2, block: 'b'),
    ],
  ),
  buildSheet(
    part: 2,
    order: 3,
    previous: 'demi-bille-1',
    block: 'b',
    exercises: [
      sheetExercise('e3', 3, block: 'b'),
      sheetExercise('e4', 4, block: 'b'),
    ],
  ),
];

/// Port de lecture sur une liste de séances (aucune écriture : le port n'en
/// déclare pas).
class FixtureSessionSheetRepository implements SessionSheetRepository {
  FixtureSessionSheetRepository(this.sheets);

  final List<SessionSheet> sheets;

  @override
  Future<List<SessionSheet>> getAll() async => List.unmodifiable(sheets);

  @override
  Future<SessionSheet?> getById(SheetId id) async {
    for (final sheet in sheets) {
      if (sheet.id == id) return sheet;
    }
    return null;
  }
}
