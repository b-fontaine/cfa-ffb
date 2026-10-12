import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const App());
}
