import 'package:billard_cfa/shared/lib/unit_of_work.dart';

/// Deux unités de travail imbriquées, pendant la migration vers Firestore
/// (ADR 0024, décision 28) : les dépôts déjà sur Firestore et ceux qui
/// restent sur drift participent à la même unité.
///
/// [outer] enveloppe [inner] : le lot Firestore (la seule étape qui peut
/// échouer après coup : réseau, règles) part **avant** la validation de la
/// transaction drift ; s'il échoue, drift est annulé avec lui. Sans lot
/// commun possible entre deux stockages, c'est le meilleur ordre : le seul
/// écart restant est une panne de l'appareil entre les deux validations.
///
/// **Hors ligne** : le lot Firestore n'est **pas attendu jusqu'à l'accusé du
/// serveur** (voir `FirestoreUnitOfWork`, `tracker`) : le SDK l'applique à son
/// cache dès l'appel, la transaction drift se ferme aussitôt, aucune écriture
/// locale n'est bloquée, et l'envoi est suivi à part (`SendStatus`). Un refus
/// du serveur arrive donc **après** la validation de drift : il ne l'annule
/// pas (écart assumé, signalé par `SendStatus.hasFailure`, FB5).
class CompositeUnitOfWork implements UnitOfWork {
  CompositeUnitOfWork({required this.outer, required this.inner});

  final UnitOfWork outer;
  final UnitOfWork inner;

  @override
  Future<T> run<T>(Future<T> Function() body) =>
      outer.run(() => inner.run(body));
}
