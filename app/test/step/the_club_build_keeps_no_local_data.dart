import 'package:flutter_test/flutter_test.dart';

import '../support/local_data_world.dart';

/// Usage: the club build keeps no local data
Future<void> theClubBuildKeepsNoLocalData(WidgetTester tester) =>
    LocalDataWorld.keepNothing(tester);
