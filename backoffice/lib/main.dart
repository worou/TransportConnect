import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'auth/auth_controller.dart';
import 'pages/config_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/demandes_page.dart';
import 'pages/litiges_page.dart';
import 'pages/login_page.dart';
import 'pages/paiements_page.dart';
import 'pages/rapports_page.dart';
import 'pages/transporteurs_page.dart';
import 'pages/utilisateurs_page.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final auth = AuthController();
  await auth.restore();
  runApp(BackOfficeApp(auth: auth));
}

class BackOfficeApp extends StatefulWidget {
  const BackOfficeApp({super.key, required this.auth});

  final AuthController auth;

  @override
  State<BackOfficeApp> createState() => _BackOfficeAppState();
}

class _BackOfficeAppState extends State<BackOfficeApp> {
  late final GoRouter _router = GoRouter(
    refreshListenable: widget.auth,
    redirect: (context, state) {
      final connecte = widget.auth.isLoggedIn;
      final surLogin = state.matchedLocation == '/connexion';
      if (!connecte && !surLogin) return '/connexion';
      if (connecte && surLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/connexion', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
          GoRoute(
            path: '/utilisateurs',
            builder: (_, state) => UtilisateursPage(
              key: ValueKey(state.uri.query),
              ongletKyc: state.uri.queryParameters['onglet'] == 'kyc',
              nom: state.uri.queryParameters['nom'],
            ),
          ),
          GoRoute(path: '/transporteurs', builder: (_, _) => const TransporteursPage()),
          GoRoute(
            path: '/demandes',
            builder: (_, state) => DemandesPage(numero: state.uri.queryParameters['numero']),
          ),
          GoRoute(path: '/paiements', builder: (_, _) => const PaiementsPage()),
          GoRoute(path: '/litiges', builder: (_, _) => const LitigesPage()),
          GoRoute(path: '/config', builder: (_, _) => const ConfigPage()),
          GoRoute(path: '/rapports', builder: (_, _) => const RapportsPage()),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AuthScope(
        controller: widget.auth,
        child: MaterialApp.router(
          title: 'TransportConnect Admin',
          debugShowCheckedModeBanner: false,
          theme: TC.theme(),
          routerConfig: _router,
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      );
}
