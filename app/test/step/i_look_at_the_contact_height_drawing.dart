import 'package:billard_cfa/shared/ui/contact_height_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the contact height drawing
Future<void> iLookAtTheContactHeightDrawing(WidgetTester tester) =>
    DiagramWorld.show(tester, const ContactHeightView());
