import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/auth.dart';
import 'screens/marchand.dart';
import 'screens/representant.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final session = Session();
  await session.restore();
  runApp(TransportConnectApp(session: session));
}

class TransportConnectApp extends StatelessWidget {
  const TransportConnectApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => SessionScope(
        session: session,
        child: MaterialApp(
          title: 'TransportConnect',
          debugShowCheckedModeBanner: false,
          theme: TC.theme(),
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const _Accueil(),
        ),
      );
}

/// Aiguillage selon la session : connexion, espace marchand, représentant ou chauffeur.
class _Accueil extends StatelessWidget {
  const _Accueil();

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    if (s.me == null) return const WelcomeScreen();
    return switch (s.role) {
      'marchand' => const MarchandShell(),
      'representant' => const RepresentantShell(),
      _ => const _EspaceIndisponible(),
    };
  }
}

/// Chauffeurs (et tout autre rôle) : pas encore d'espace dédié dans l'app.
class _EspaceIndisponible extends StatelessWidget {
  const _EspaceIndisponible();

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: Alignment.centerLeft, child: TcLogo()),
            const Spacer(),
            const Icon(Icons.local_shipping_outlined, size: 56, color: TC.primary),
            const SizedBox(height: 16),
            Text('Bonjour ${s.me?['nom_complet'] ?? ''}', textAlign: TextAlign.center, style: TC.h2),
            const SizedBox(height: 8),
            Text(
              'L\'espace chauffeur arrive dans une prochaine version. Votre transporteur vous communique vos livraisons en attendant.',
              textAlign: TextAlign.center,
              style: TC.bodyMuted,
            ),
            const Spacer(),
            OutlinedButton(onPressed: s.logout, child: const Text('Se déconnecter')),
          ]),
        ),
      ),
    );
  }
}
