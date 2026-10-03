import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'evaluation.dart';
import 'profil.dart';

/// Espace représentant : Accueil, Missions, Activité, Profil.
class RepresentantShell extends StatefulWidget {
  const RepresentantShell({super.key});

  @override
  State<RepresentantShell> createState() => _RepresentantShellState();
}

class _RepresentantShellState extends State<RepresentantShell> {
  int _onglet = 0;
  final _cles = List.generate(4, (_) => GlobalKey());

  void _aller(int i) => setState(() {
        _onglet = i;
        _cles[i] = GlobalKey();
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _onglet, children: [
            RepresentantHome(key: _cles[0], onMissions: () => _aller(1)),
            MissionsScreen(key: _cles[1]),
            ActiviteScreen(key: _cles[2]),
            ProfilScreen(key: _cles[3], onDemandes: () => _aller(2)),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: _aller,
          backgroundColor: TC.white,
          indicatorColor: TC.primary100,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: TC.primary), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment, color: TC.primary), label: 'Missions'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights, color: TC.primary), label: 'Activité'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: TC.primary), label: 'Profil'),
          ],
        ),
      );
}

/// Missions disponibles : demandes en attente dont la ville de départ est dans la zone du représentant.
Future<List<Map<String, dynamic>>> chargerMissions(Session s) async {
  final zones = ((s.me?['zones_intervention'] as List?) ?? const []).cast<String>().toSet();
  final demandes = await s.api.list('/api/demandes', query: {'statut': 'EN_ATTENTE'});
  return demandes.where((d) => zones.isEmpty || zones.contains(d['ville_depart'])).toList();
}

String _quantite(Map<String, dynamic> d) => [
      if (d['poids_estime'] != null) '${nombre(num.parse('${d['poids_estime']}'))} kg',
      if (d['volume_estime'] != null) '${d['volume_estime']} m³',
    ].join(' · ');

const _dispos = {'disponible': 'Disponible', 'occupe': 'Occupé', 'hors_ligne': 'Hors ligne'};
const _dispoCouleurs = {'disponible': TC.success, 'occupe': Color(0xFF9A5B0B), 'hors_ligne': TC.muted};

/// R01 — Accueil représentant.
class RepresentantHome extends StatefulWidget {
  const RepresentantHome({super.key, required this.onMissions});

  final VoidCallback onMissions;

  @override
  State<RepresentantHome> createState() => _RepresentantHomeState();
}

class _RepresentantHomeState extends State<RepresentantHome> {
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>, Map<String, dynamic>?)>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>, Map<String, dynamic>?)> _load() async {
    final s = context.session;
    final r = await Future.wait([chargerMissions(s), s.api.list('/api/evaluations', query: {'representant': s.meIri})]);
    final evaluations = r[1];
    // Mission en cours : évaluation pas encore soumise, ou soumise sans devis
    final encours = evaluations.where((e) => e['statut_devis'] == null && e['statut_demande'] != 'ANNULE').firstOrNull;
    final demande = encours == null ? null : await s.api.get(encours['demande'] as String);
    return (r[0], evaluations, encours == null ? null : {...encours, 'demande_detail': demande});
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _changerDispo() async {
    final s = context.session;
    final choix = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in _dispos.entries)
            ListTile(
              leading: Icon(Icons.circle, size: 14, color: _dispoCouleurs[e.key]),
              title: Text(e.value),
              trailing: s.me?['disponibilite'] == e.key ? const Icon(Icons.check, color: TC.primary) : null,
              onTap: () => Navigator.pop(c, e.key),
            ),
        ]),
      ),
    );
    if (choix == null || !mounted) return;
    if (await act(context, () => s.api.patch(s.meIri, {'disponibilite': choix}))) await s.reloadMe();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    final me = s.me!;
    final dispo = me['disponibilite'] as String? ?? 'hors_ligne';
    final zones = ((me['zones_intervention'] as List?) ?? const []).map((z) => s.ville(z as String)?['nom_ville']).whereType<String>().join(', ');
    return Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>, Map<String, dynamic>?)>(
      future: _future,
      onRetry: _refresh,
      builder: (data) {
        final (missions, evaluations, encours) = data;
        final aujourdhui = DateUtils.dateOnly(DateTime.now());
        final duJour = evaluations.where((e) => DateUtils.dateOnly(DateTime.parse(e['date_acceptation'] as String).toLocal()) == aujourdhui).length;
        final devis7j = evaluations
            .where((e) => e['prix_devis'] != null && DateTime.parse(e['date_acceptation'] as String).isAfter(DateTime.now().subtract(const Duration(days: 7))))
            .length;
        final historique = evaluations.where((e) => e['statut_devis'] != null).take(4).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            Row(children: [
              Initials(me['nom_complet'] as String?),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${me['nom_transporteur'] ?? 'Représentant'}', style: TC.small),
                  Text(me['nom_complet'] as String? ?? me['telephone'] as String, style: TC.h2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Material(
              color: TC.white,
              borderRadius: BorderRadius.circular(TC.radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(TC.radius),
                onTap: _changerDispo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.circle, size: 12, color: _dispoCouleurs[dispo]),
                    const SizedBox(width: 8),
                    Text(_dispos[dispo]!, style: TC.strong),
                    const SizedBox(width: 8),
                    Expanded(child: Text(zones.isEmpty ? 'Aucune zone' : 'Zone : $zones', style: TC.small, overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.expand_more, color: TC.muted),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: TC.primary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onMissions,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: TC.secondary, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.notifications_active_outlined, color: TC.ink),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          missions.isEmpty ? 'Aucune nouvelle mission' : '${missions.length} mission${missions.length > 1 ? 's' : ''} disponible${missions.length > 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: TC.white),
                        ),
                        Text('Dans votre zone', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDCE6F2))),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: TC.white),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Tuile(valeur: '$duJour', label: 'Missions du jour')),
              const SizedBox(width: 12),
              Expanded(child: _Tuile(valeur: '$devis7j', label: 'Devis envoyés (7 j)')),
            ]),
            if (encours != null) ...[
              const SizedBox(height: 18),
              Text('Mission en cours', style: TC.h3),
              const SizedBox(height: 10),
              _MissionEnCours(encours, onRetour: _refresh),
            ],
            if (historique.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Historique', style: TC.h3),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < historique.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _LigneEvaluation(historique[i]),
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

class _Tuile extends StatelessWidget {
  const _Tuile({required this.valeur, required this.label});

  final String valeur;
  final String label;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valeur, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: TC.ink)),
          Text(label, style: TC.small),
        ]),
      );
}

class _MissionEnCours extends StatelessWidget {
  const _MissionEnCours(this.e, {required this.onRetour});

  final Map<String, dynamic> e;
  final VoidCallback onRetour;

  @override
  Widget build(BuildContext context) {
    final d = e['demande_detail'] as Map<String, dynamic>;
    final etape = e['date_checkin'] == null ? 'À évaluer' : (e['date_soumission'] == null ? 'Évaluation en cours' : 'Prix à envoyer');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${e['numero_demande']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: TC.muted))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF4ECF8), borderRadius: BorderRadius.circular(20)),
            child: Text(etape, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6C3483))),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${d['nom_marchand'] ?? 'Marchand'} · ${Statuts.types[d['type_marchandise']]} ${_quantite(d)}', style: TC.strong),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.place_outlined, size: 16, color: TC.muted),
          const SizedBox(width: 4),
          Expanded(child: Text('${d['nom_ville_depart']}, ${d['adresse_depart']}', style: TC.small)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openMaps('${d['adresse_depart']}, ${d['nom_ville_depart']}'),
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: const Text('Itinéraire'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EvaluationScreen(evaluationId: e['id'] as String)));
                onRetour();
              },
              child: const Text('Continuer'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _LigneEvaluation extends StatelessWidget {
  const _LigneEvaluation(this.e);

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final (label, couleur) = switch (e['statut_devis']) {
      'accepte' => ('Accepté', TC.success),
      'refuse' => ('Refusé', TC.error),
      'en_negociation' => ('Négociation', const Color(0xFF873600)),
      'expire' => ('Expiré', TC.muted),
      _ => ('Envoyé', TC.primary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['numero_demande']} · ${e['trajet']}', style: TC.strong.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis),
            Text('$label · ${date(e['date_acceptation'])}', style: TC.caption.copyWith(color: couleur)),
          ]),
        ),
        Text(fcfa(e['prix_devis']), style: TC.strong.copyWith(fontSize: 14)),
      ]),
    );
  }
}

/// R02 — Missions disponibles dans la zone.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  String _filtre = 'toutes';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= chargerMissions(context.session);
  }

  Future<void> _refresh() async {
    setState(() => _future = chargerMissions(context.session));
    await _future;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [Expanded(child: Text('Missions disponibles', style: TC.h2))]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Segmented(options: const {'toutes': 'Toutes', 'express': 'Express'}, value: _filtre, onChanged: (v) => setState(() => _filtre = v)),
        ),
        Expanded(
          child: Loader<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _refresh,
            builder: (all) {
              final list = _filtre == 'express' ? all.where((d) => d['urgence'] == 'express').toList() : all;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: list.isEmpty
                    ? ListView(padding: const EdgeInsets.all(20), children: [
                        Panel(child: Text('Aucune mission disponible dans votre zone pour le moment.', style: TC.bodyMuted)),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => MissionCard(list[i], onChange: _refresh),
                      ),
              );
            },
          ),
        ),
      ]);
}

Future<void> accepterMission(BuildContext context, Map<String, dynamic> d, {required VoidCallback onDone}) async {
  final s = context.session;
  try {
    final e = await s.api.post('/api/evaluations', {'demande': '/api/demandes/${d['id']}', 'representant': s.meIri});
    if (!context.mounted) return;
    toast(context, 'Mission ${d['numero']} acceptée.');
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EvaluationScreen(evaluationId: e['id'] as String)));
    onDone();
  } catch (e) {
    if (context.mounted) toast(context, '$e', error: true);
  }
}

class MissionCard extends StatelessWidget {
  const MissionCard(this.d, {super.key, required this.onChange});

  final Map<String, dynamic> d;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('${d['nom_ville_depart']} → ${d['nom_ville_arrivee']}', style: TC.strong.copyWith(fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: d['urgence'] == 'express' ? TC.secondary.withValues(alpha: 0.15) : TC.segment,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(d['urgence'] == 'express' ? 'EXPRESS' : 'NORMAL',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: d['urgence'] == 'express' ? const Color(0xFF9A5B0B) : TC.muted)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${d['nom_marchand'] ?? 'Marchand'} · ${Statuts.types[d['type_marchandise']]} ${_quantite(d)}', style: TC.body.copyWith(fontSize: 14)),
          Text('Enlèvement le ${date(d['date_enlevement'])} · ${d['adresse_depart']}', style: TC.small),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MissionDetailScreen(d)));
                  onChange();
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: const Text('Détails'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => accepterMission(context, d, onDone: onChange),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: const Text('Accepter'),
              ),
            ),
          ]),
        ]),
      );
}

/// R03 — Détail d'une mission.
class MissionDetailScreen extends StatefulWidget {
  const MissionDetailScreen(this.d, {super.key});

  final Map<String, dynamic> d;

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen> {
  late final Future<List<Map<String, dynamic>>> _photos = context.api.list('/api/photos', query: {'demande': '/api/demandes/${widget.d['id']}'});

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final tel = (d['contact_telephone'] as String?) ?? d['telephone_marchand'] as String?;
    Widget info(String label, String valeur) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(label, style: TC.bodyMuted)),
            Expanded(child: Text(valeur, style: TC.strong)),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: '${d['numero']}', subtitle: 'Publiée le ${dateHeure(d['created_at'])}'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${d['nom_ville_depart']} → ${d['nom_ville_arrivee']}', style: TC.h3.copyWith(fontSize: 18))),
                    if (d['urgence'] == 'express')
                      Text('EXPRESS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF9A5B0B))),
                  ]),
                  const SizedBox(height: 4),
                  Text([if (d['distance_km'] != null) '${nombre(num.parse('${d['distance_km']}'))} km', 'Enlèvement souhaité le ${date(d['date_enlevement'])}'].join(' · '), style: TC.small),
                ]),
              ),
              const SizedBox(height: 12),
              Panel(
                child: Row(children: [
                  Initials(d['contact_nom'] as String? ?? d['nom_marchand'] as String?),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Marchand · contact sur place', style: TC.caption),
                      Text('${d['contact_nom'] ?? d['nom_marchand'] ?? '—'}', style: TC.strong),
                    ]),
                  ),
                  if (tel != null) SquareButton(icon: Icons.phone_outlined, tooltip: 'Appeler', onPressed: () => appeler(tel)),
                ]),
              ),
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text("Adresse d'enlèvement", style: TC.caption),
                  Text('${d['adresse_depart']}, ${d['nom_ville_depart']}', style: TC.strong),
                  if (d['lat_depart'] != null) Text('Position GPS fournie par le marchand', style: TC.small),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => openMaps(d['lat_depart'] != null ? '${d['lat_depart']},${d['lng_depart']}' : '${d['adresse_depart']}, ${d['nom_ville_depart']}'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Ouvrir dans Maps'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Marchandise déclarée', style: TC.h3),
              const SizedBox(height: 6),
              Panel(
                child: Column(children: [
                  info('Type', '${Statuts.types[d['type_marchandise']]}'),
                  info('Description', '${d['description']}'),
                  info('Quantité', _quantite(d)),
                  if (d['instructions'] != null) info('Instructions', '${d['instructions']}'),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _photos,
                    builder: (c, s) => s.hasData && s.data!.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: s.data!.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network('${s.data![i]['url']}', width: 72, height: 72, fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: TC.segment, child: const Icon(Icons.image_not_supported_outlined))),
                                ),
                              ),
                            ),
                          )
                        : info('Photos', s.hasData ? 'Aucune' : '…'),
                  ),
                ]),
              ),
            ]),
          ),
          BottomActions(children: [
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Refuser')),
            FilledButton(onPressed: () => accepterMission(context, d, onDone: () => Navigator.of(context).maybePop()), child: const Text('Accepter la mission')),
          ]),
        ]),
      ),
    );
  }
}

/// R07 — Activité : évaluations, devis envoyés et acceptés (données réelles, pas de modèle de rémunération).
class ActiviteScreen extends StatefulWidget {
  const ActiviteScreen({super.key});

  @override
  State<ActiviteScreen> createState() => _ActiviteScreenState();
}

class _ActiviteScreenState extends State<ActiviteScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.api.list('/api/evaluations', query: {'representant': context.session.meIri});
  }

  Future<void> _refresh() async {
    setState(() => _future = context.api.list('/api/evaluations', query: {'representant': context.session.meIri}));
    await _future;
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        future: _future,
        onRetry: _refresh,
        builder: (evals) {
          final now = DateTime.now();
          final semaine = evals.where((e) => DateTime.parse(e['date_acceptation'] as String).isAfter(now.subtract(const Duration(days: 7)))).toList();
          final acceptes = evals.where((e) => e['statut_devis'] == 'accepte').toList();
          final montant = acceptes.fold<num>(0, (t, e) => t + ((e['prix_devis'] as num?) ?? 0));
          final jours = [for (var i = 6; i >= 0; i--) DateUtils.dateOnly(now.subtract(Duration(days: i)))];
          final parJour = [for (final j in jours) evals.where((e) => DateUtils.dateOnly(DateTime.parse(e['date_acceptation'] as String).toLocal()) == j).length];
          final maxJour = parJour.fold<int>(1, (m, v) => v > m ? v : m);
          const lettres = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
              Text('Mon activité', style: TC.h2),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: TC.primary, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Devis acceptés (total)', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFDCE6F2))),
                  Text(fcfa(montant).replaceAll(' F', ' FCFA'), style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w700, color: TC.white)),
                  Text('${acceptes.length} devis accepté(s) sur ${evals.where((e) => e['prix_devis'] != null).length} envoyé(s)',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDCE6F2))),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Tuile(valeur: '${semaine.length}', label: 'Missions (7 j)')),
                const SizedBox(width: 12),
                Expanded(child: _Tuile(valeur: '${evals.where((e) => e['statut_devis'] == null).length}', label: 'En cours')),
              ]),
              const SizedBox(height: 16),
              Text('7 derniers jours', style: TC.h3),
              const SizedBox(height: 10),
              Panel(
                child: SizedBox(
                  height: 130,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text('${parJour[i]}', style: TC.caption),
                          const SizedBox(height: 4),
                          Container(
                            height: 80 * parJour[i] / maxJour + 2,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: i == 6 ? TC.secondary : TC.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                          ),
                          const SizedBox(height: 6),
                          Text(lettres[jours[i].weekday - 1], style: TC.caption),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Text('Dernières missions', style: TC.h3),
              const SizedBox(height: 10),
              if (evals.isEmpty)
                Panel(child: Text('Aucune mission pour le moment.', style: TC.bodyMuted))
              else
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < evals.length && i < 10; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _LigneEvaluation(evals[i]),
                    ],
                  ]),
                ),
            ]),
          );
        },
      );
}
