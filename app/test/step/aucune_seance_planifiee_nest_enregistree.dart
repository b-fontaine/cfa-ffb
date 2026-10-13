import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> aucuneSeancePlanifieeNestEnregistree(WidgetTester tester) async {
  expect(await getIt<SessionRepository>().getAll(), isEmpty);
}
