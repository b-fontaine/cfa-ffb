import 'dart:async';

import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/auth/auth_refresh.dart';
import 'package:billard_cfa/app/club_scoped.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthCubit _auth = getIt<AuthCubit>();
  late final AuthRefresh _refresh = AuthRefresh(_auth);
  late final GoRouter _router = buildRouter(auth: _auth, refresh: _refresh);

  @override
  void initState() {
    super.initState();
    // Lance la session : le routeur affiche l'écran de démarrage jusqu'à ce que
    // l'état soit connu (ADR 0024, décision 31).
    unawaited(_auth.start());
  }

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: _auth,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        routerConfig: _router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        builder: (context, child) => ClubScoped(child: child!),
      ),
    );
  }
}
