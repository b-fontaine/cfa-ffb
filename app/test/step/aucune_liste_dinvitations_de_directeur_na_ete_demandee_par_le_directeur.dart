import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

/// Chaque requête du directeur sur les invitations porte le club et un rôle
/// qu'il invite : jamais celui de directeur, jamais tous les rôles.
Future<void> aucuneListeDinvitationsDeDirecteurNaEteDemandeeParLeDirecteur(
  WidgetTester tester,
) async {
  final queries = OperationsWorld.current.store.invitationQueries;
  expect(queries, isNotEmpty, reason: 'aucune liste demandée');
  for (final query in queries) {
    expect(query, isA<AllEqual>());
    final clauses = {
      for (final clause in (query as AllEqual).clauses)
        clause.field: clause.value,
    };
    expect(clauses['clubId'], 'c1');
    expect(['teacher', 'student', 'guardian'], contains(clauses['role']));
  }
}
