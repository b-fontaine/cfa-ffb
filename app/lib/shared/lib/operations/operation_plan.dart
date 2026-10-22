import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';

/// Un lot de travail : au plus [OperationLimits.lotSize] écritures **marqueur
/// compris**, appliquées **en un seul lot atomique** avec l'avancement du
/// marqueur. [apply] ne fait que les écritures de l'opération (les dépôts
/// habituels, ou des suppressions et fusions par chemin) : le marqueur est du
/// ressort du magasin d'opérations.
final class OperationLot {
  const OperationLot({required this.writes, required this.apply});

  /// Un lot sans écriture de données : il ne fait qu'avancer le marqueur (une
  /// étape qui n'a plus rien à faire).
  static final OperationLot empty = OperationLot(writes: 0, apply: () async {});

  /// Écritures que [apply] fait (estimation haute : sert à remplir un lot et à
  /// compter le plafond du jour).
  final int writes;
  final Future<void> Function() apply;
}

/// Une étape d'une opération : le travail **qui reste**, recalculé d'après
/// l'**état courant** du club à chaque appel (jamais d'après un plan figé). Une
/// étape dont le travail est fait rend une liste vide : c'est ce qui fait
/// converger la reprise, que l'exécution ait été coupée, rejouée ou menée par
/// deux appareils.
abstract interface class OperationStage {
  /// Les lots qui restent, de [OperationLimits.lotSize] − 1 écritures au plus
  /// chacun (le marqueur prend la dernière).
  Future<List<OperationLot>> remaining(int maxWrites);
}

/// Une opération reprenable : des étapes ordonnées. La **dernière** étape
/// achève l'opération (elle supprime ce que l'opération devait supprimer en
/// dernier, la fiche d'un élève par exemple) ; le lot qui la termine supprime
/// aussi le marqueur.
abstract interface class ResumableOperation {
  OperationKind get kind;

  /// Identifiant de l'opération ([operationKey]).
  String get key;

  /// Les termes écrits au marqueur (clôture seulement).
  ClosureTerms? get terms;

  /// L'opération est-elle déjà achevée alors qu'aucun marqueur n'existe ? (La
  /// fiche de l'élève n'existe plus ; la saison est close.) Lue avant de
  /// commencer et quand le marqueur a disparu en cours de route (un autre
  /// appareil a terminé).
  Future<bool> isAlreadyDone();

  List<OperationStage> get stages;
}

/// Les bornes d'une opération (ADR 0024, décision 19 ; mêmes valeurs que
/// l'import d'une sauvegarde).
final class OperationLimits {
  const OperationLimits({this.lotSize = 400, this.dailyWrites = 10000})
    : assert(lotSize >= 2, 'un lot porte au moins une écriture et le marqueur');

  /// Écritures d'un lot **marqueur compris** : 400 au plus, sous les 500 d'un
  /// `WriteBatch`.
  final int lotSize;

  /// Écritures qu'une opération se permet par jour et par appareil : la
  /// moitié du plafond de 20 000 écritures par jour du plan Spark.
  final int dailyWrites;

  /// Écritures de données d'un lot.
  int get dataWrites => lotSize - 1;
}
