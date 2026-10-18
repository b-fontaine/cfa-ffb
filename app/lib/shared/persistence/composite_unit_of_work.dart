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
class CompositeUnitOfWork implements UnitOfWork {
  CompositeUnitOfWork({required this.outer, required this.inner});

  final UnitOfWork outer;
  final UnitOfWork inner;

  @override
  Future<T> run<T>(Future<T> Function() body) =>
      outer.run(() => inner.run(body));
}
