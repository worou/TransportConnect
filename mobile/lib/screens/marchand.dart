import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'nouvelle_demande.dart';
import 'profil.dart';
import 'suivi.dart';

/// Espace marchand : Accueil, Demandes, + (nouvelle demande), Messages, Profil.
class MarchandShell extends StatefulWidget {
  const MarchandShell({super.key});

  @override
  State<MarchandShell> createState() => _MarchandShellState();
}

class _MarchandShellState extends State<MarchandShell> {
  int _onglet = 0;
  final _cles = List.generate(4, (_) => GlobalKey());

  Future<void> _nouvelle() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NouvelleDemandeScreen()));
    setState(() => _cles[0] = GlobalKey()); // recharge l'accueil
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _onglet, children: [
            MarchandHome(key: _cles[0], onNouvelle: _nouvelle, onToutVoir: () => setState(() => _onglet = 1)),
            DemandesList(key: _cles[1]),
            NotificationsScreen(key: _cles[2]),
            ProfilScreen(key: _cles[3], onDemandes: () => setState(() => _onglet = 1)),
          ]),
        ),
        bottomNavigationBar: _NavBar(
          index: _onglet,
          onTap: (i) => setState(() {
            _onglet = i;
            _cles[i] = GlobalKey(); // données fraîches à chaque visite
          }),
          onPlus: _nouvelle,
        ),
      );
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap, required this.onPlus});

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onPlus;

  Widget _item(int i, IconData icon, String label) => Expanded(
        child: InkWell(
          onTap: () => onTap(i),
          child: SizedBox(
            height: 56,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 22, color: i == index ? TC.primary : TC.muted),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: i == index ? FontWeight.w600 : FontWeight.w500, color: i == index ? TC.primary : TC.muted)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        // Hauteur fixe : sans elle, le bouton central s'étire et la barre occupe tout l'écran
        height: 64 + MediaQuery.paddingOf(context).bottom,
        padding: EdgeInsets.only(left: 8, right: 8, bottom: MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: TC.white, border: Border(top: BorderSide(color: TC.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _item(0, Icons.home_outlined, 'Accueil'),
          _item(1, Icons.inventory_2_outlined, 'Demandes'),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -14),
                child: Tooltip(
                  message: 'Nouvelle demande',
                  child: Material(
                    color: TC.secondary,
                    shape: const CircleBorder(side: BorderSide(color: TC.white, width: 4)),
                    elevation: 4,
                    shadowColor: TC.secondary.withValues(alpha: 0.5),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onPlus,
                      child: const SizedBox(width: 56, height: 56, child: Icon(Icons.add, color: TC.ink, size: 26)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _item(2, Icons.chat_bubble_outline, 'Messages'),
          _item(3, Icons.person_outline, 'Profil'),
        ]),
      );
}

/// M04 — Accueil marchand.
class MarchandHome extends StatefulWidget {
  const MarchandHome({super.key, required this.onNouvelle, required this.onToutVoir});

  final VoidCallback onNouvelle;
  final VoidCallback onToutVoir;

  @override
  State<MarchandHome> createState() => _MarchandHomeState();
}

class _MarchandHomeState extends State<MarchandHome> {
  Future<(List<Map<String, dynamic>>, int)>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(List<Map<String, dynamic>>, int)> _load() async {
    final api = context.api;
    final r = await Future.wait([api.list('/api/demandes'), api.list('/api/notifications', query: {'est_lue': 'false'})]);
    return (r[0], r[1].length);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final me = context.session.me!;
    return Loader<(List<Map<String, dynamic>>, int)>(
      future: _future,
      onRetry: _refresh,
      builder: (data) {
        final (demandes, nonLues) = data;
        final enCours = demandes.where((d) => Statuts.enCours.contains(d['statut'])).toList();
        final livrees = demandes.where((d) => d['statut'] == 'LIVRE').take(3).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            Row(children: [
              Initials(me['nom_complet'] as String?),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bonjour,', style: TC.small),
                  Text(me['nom_complet'] as String? ?? me['telephone'] as String, style: TC.h2, overflow: TextOverflow.ellipsis),
                ]),
              ),
              SquareButton(
                icon: Icons.notifications_none,
                tooltip: nonLues > 0 ? '$nonLues notification(s) non lue(s)' : 'Notifications',
                dot: nonLues > 0,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: NotificationsScreen(withBack: true))))),
              ),
            ]),
            const SizedBox(height: 16),
            Material(
              color: TC.primary,
              borderRadius: BorderRadius.circular(20),
              elevation: 6,
              shadowColor: TC.primary.withValues(alpha: 0.35),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onNouvelle,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Nouvelle demande', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: TC.white)),
                        const SizedBox(height: 6),
                        Text('Expédiez une marchandise vers une autre ville', style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: const Color(0xFFDCE6F2))),
                      ]),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: TC.secondary, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.add, color: TC.ink, size: 28),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle('Demandes en cours', action: demandes.isEmpty ? null : 'Tout voir', onAction: widget.onToutVoir),
            const SizedBox(height: 10),
            if (enCours.isEmpty)
              Panel(child: Text('Aucune demande en cours. Créez votre première demande avec le bouton ci-dessus.', style: TC.bodyMuted))
            else
              for (final d in enCours.take(4)) ...[DemandeCard(d), const SizedBox(height: 12)],
            if (livrees.isNotEmpty) ...[
              const SizedBox(height: 8),
              const _SectionTitle('Historique récent'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(children: [
                  for (var i = 0; i < livrees.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    InkWell(
                      onTap: () => ouvrirSuivi(context, livrees[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: TC.successBg, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.check, size: 18, color: TC.success),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${livrees[i]['nom_ville_depart']} → ${livrees[i]['nom_ville_arrivee']}', style: TC.strong.copyWith(fontSize: 14)),
                              Text('Livré · ${livrees[i]['numero']}', style: TC.caption),
                            ]),
                          ),
                          Text(date(livrees[i]['updated_at']), style: TC.small),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text, style: TC.h3)),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]);
}

/// Carte d'une demande : numéro, statut, trajet, avancement.
class DemandeCard extends StatelessWidget {
  const DemandeCard(this.d, {super.key});

  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final (_, _, avancement) = Statuts.demande[d['statut']] ?? ('', TC.muted, 0.0);
    return Panel(
      onTap: () => ouvrirSuivi(context, d),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${d['numero']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: TC.muted))),
          StatusBadge(d['statut'] as String?),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Flexible(child: Text('${d['nom_ville_depart']}', style: TC.strong.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 16, color: TC.muted)),
          Flexible(child: Text('${d['nom_ville_arrivee']}', style: TC.strong.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis)),
        ]),
        if (d['statut'] != 'ANNULE') ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: avancement, minHeight: 6, color: TC.primary, backgroundColor: TC.border),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Enlèvement le ${date(d['date_enlevement'])}', style: TC.small)),
          if (d['statut'] != 'ANNULE') Text('${(avancement * 100).round()} %', style: TC.small),
        ]),
      ]),
    );
  }
}

/// Liste de toutes les demandes du marchand.
class DemandesList extends StatefulWidget {
  const DemandesList({super.key});

  @override
  State<DemandesList> createState() => _DemandesListState();
}

class _DemandesListState extends State<DemandesList> {
  Future<List<Map<String, dynamic>>>? _future;
  bool _toutes = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.api.list('/api/demandes');
  }

  Future<void> _refresh() async {
    setState(() => _future = context.api.list('/api/demandes'));
    await _future;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [Expanded(child: Text('Mes demandes', style: TC.h2))]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Segmented(
            options: const {'cours': 'En cours', 'toutes': 'Toutes'},
            value: _toutes ? 'toutes' : 'cours',
            onChanged: (v) => setState(() => _toutes = v == 'toutes'),
          ),
        ),
        Expanded(
          child: Loader<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _refresh,
            builder: (all) {
              final list = _toutes ? all : all.where((d) => Statuts.enCours.contains(d['statut'])).toList();
              return RefreshIndicator(
                onRefresh: _refresh,
                child: list.isEmpty
                    ? ListView(padding: const EdgeInsets.all(20), children: [
                        Panel(child: Text(_toutes ? 'Aucune demande pour le moment.' : 'Aucune demande en cours.', style: TC.bodyMuted)),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => DemandeCard(list[i]),
                      ),
              );
            },
          ),
        ),
      ]);
}

/// Messages : notifications de la plateforme (prix proposé, paiement, livraison…).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.withBack = false});

  final bool withBack;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.api.list('/api/notifications');
  }

  Future<void> _refresh() async {
    setState(() => _future = context.api.list('/api/notifications'));
    await _future;
  }

  Future<void> _lire(Map<String, dynamic> n) async {
    if (n['est_lue'] == true) return;
    await act(context, () => context.api.patch('/api/notifications/${n['id']}', {'est_lue': true}));
    _refresh();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        if (widget.withBack)
          const TopBar(title: 'Notifications')
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [Expanded(child: Text('Messages', style: TC.h2))]),
          ),
        Expanded(
          child: Loader<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _refresh,
            builder: (list) => RefreshIndicator(
              onRefresh: _refresh,
              child: list.isEmpty
                  ? ListView(padding: const EdgeInsets.all(20), children: [
                      Panel(child: Text('Aucun message. Vous serez prévenu ici à chaque étape de vos demandes.', style: TC.bodyMuted)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final n = list[i];
                        final lue = n['est_lue'] == true;
                        return Panel(
                          onTap: () => _lire(n),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: lue ? Colors.transparent : TC.secondary, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${n['titre']}', style: TC.strong),
                                const SizedBox(height: 4),
                                Text('${n['contenu']}', style: TC.body.copyWith(fontSize: 14)),
                                const SizedBox(height: 6),
                                Text(dateHeure(n['date_envoi']), style: TC.caption),
                              ]),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ),
        ),
      ]);
}
