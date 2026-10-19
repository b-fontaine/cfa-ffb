import 'package:flutter_test/flutter_test.dart';

import '../support/family_world.dart';

/// Usage: the access of {'anne@example.org'} is removed by the club
///
/// Le club supprime le `member` du compte : les règles du serveur ne lui
/// laissent plus rien lire, les écoutes ouvertes sont refusées et se ferment.
Future<void> theAccessOfIsRemovedByTheClub(WidgetTester tester, String email) =>
    FamilyWorld.removeAccess(tester, email);
