import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> ouvrirSuivi(BuildContext context, Map<String, dynamic> d) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SuiviDemandeScreen(id: d['id'] as String)));

/// Tout ce qu'il faut pour suivre une demande : demande, historique, dernière évaluation, devis, livraison.
class Dossier {
  Dossier(this.demande, this.historique, this.evaluation, this.devis, this.livraison);

  final Map<String, dynamic> demande;
  final List<Map<String, dynamic>> historique;
  final Map<String, dynamic>? evaluation;
  final Map<String, dynamic>? devis;
  final Map<String, dynamic>? livraison;

  String get statut => demande['statut'] as String;
}

Future<Dossier> _chargerDossier(Api api, String id) async {
  final iri = '/api/demandes/$id';
  final r = await Future.wait([
    api.get(iri),
    api.list('/api/historique_statuts', query: {'demande': iri}),
    api.list('/api/evaluations', query: {'demande': iri}),
    api.list('/api/livraisons', query: {'demande': iri}),
  ]);
  final evaluations = r[2] as List<Map<String, dynamic>>;
  final evaluation = evaluations.isEmpty ? null : evaluations.first; // tri : la plus récente d'abord
  Map<String, dynamic>? devis;
  if (evaluation != null) {
    final l = await api.list('/api/devis', query: {'evaluation': '/api/evaluations/${evaluation['id']}'});
    devis = l.isEmpty ? null : l.first;
  }
  final livraisons = r[3] as List<Map<String, dynamic>>;
  return Dossier(r[0] as Map<String, dynamic>, r[1] as List<Map<String, dynamic>>, evaluation, devis, livraisons.isEmpty ? null : livraisons.first);
}

/// M08 — Suivi d'une demande.
class SuiviDemandeScreen extends StatefulWidget {
  const SuiviDemandeScreen({super.key, required this.id});

  final String id;

  @override
  State<SuiviDemandeScreen> createState() => _SuiviDemandeScreenState();
}

class _SuiviDemandeScreenState extends State<SuiviDemandeScreen> {
  Future<Dossier>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _chargerDossier(context.api, widget.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _chargerDossier(context.api, widget.id));
    await _future;
  }

  Future<void> _ouvrir(Widget ecran) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran));
    _refresh();
  }

  Future<void> _annuler(Dossier d) async {
    if (!await confirm(context, 'Annuler la demande', 'La demande ${d.demande['numero']} sera annulée. Cette action est définitive.', ok: 'Annuler la demande', danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await act(context, () => context.api.patch('/api/demandes/${widget.id}', {'statut': 'ANNULE'}), success: 'Demande annulée.')) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Loader<Dossier>(
            future: _future,
            onRetry: _refresh,
            builder: (d) {
              final dm = d.demande;
              final quantite = [
                if (dm['poids_estime'] != null) '${nombre(num.parse('${dm['poids_estime']}'))} kg',
                if (dm['volume_estime'] != null) '${dm['volume_estime']} m³',
              ].join(' · ');
              return Column(children: [
                TopBar(title: '${dm['numero']}', subtitle: 'Créée le ${dateHeure(dm['created_at'])}'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
                      Panel(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('${dm['nom_ville_depart']} → ${dm['nom_ville_arrivee']}', style: TC.h3.copyWith(fontSize: 17)),
                            ),
                            StatusBadge(d.statut),
                          ]),
                          const SizedBox(height: 8),
                          Text('${Statuts.types[dm['type_marchandise']] ?? dm['type_marchandise']} · $quantite · ${dm['urgence'] == 'express' ? 'Express' : 'Normale'}',
                              style: TC.small),
                          Text('${dm['description']}', style: TC.small),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      if (d.statut == 'ANNULE')
                        const InfoBox('Cette demande a été annulée.', icon: Icons.block)
                      else ...[
                        Text('Progression', style: TC.h3),
                        const SizedBox(height: 10),
                        _Timeline(d),
                      ],
                      if (d.evaluation != null) ...[
                        const SizedBox(height: 16),
                        _PersonneCard(
                          nom: d.evaluation!['nom_representant'] as String?,
                          role: 'Représentant · ${d.evaluation!['nom_transporteur'] ?? 'Transporteur'}',
                          telephone: d.evaluation!['telephone_representant'] as String?,
                        ),
                      ],
                    ]),
                  ),
                ),
                _actions(d),
              ]);
            },
          ),
        ),
      );

  Widget _actions(Dossier d) {
    final boutons = <Widget>[];
    if (['PRIX_PROPOSE', 'EN_NEGOCIATION', 'PAIEMENT_EN_ATTENTE'].contains(d.statut) && d.devis != null) {
      boutons.add(FilledButton(onPressed: () => _ouvrir(EstimationScreen(demandeId: widget.id)), child: const Text("Voir l'estimation")));
    } else if (['PAYE', 'EN_TRANSIT', 'LIVRE'].contains(d.statut)) {
      boutons.add(FilledButton(onPressed: () => _ouvrir(SuiviCarteScreen(demandeId: widget.id)), child: const Text('Suivre la livraison')));
    }
    final annulable = Statuts.annulables.contains(d.statut);
    if (boutons.isEmpty && !annulable) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(color: TC.white, border: Border(top: BorderSide(color: TC.border))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...boutons,
        if (annulable)
          TextButton(
            onPressed: () => _annuler(d),
            style: TextButton.styleFrom(foregroundColor: TC.error),
            child: const Text('Annuler la demande'),
          ),
      ]),
    );
  }
}

/// Frise des étapes, datées par l'historique des statuts.
class _Timeline extends StatelessWidget {
  const _Timeline(this.d);

  final Dossier d;

  @override
  Widget build(BuildContext context) {
    final dates = <String, String>{};
    for (final h in d.historique) {
      dates.putIfAbsent(h['nouveau_statut'] as String, () => h['date_changement'] as String);
    }
    final ordre = Statuts.etapes.map((e) => e.$1).toList();
    // Étape courante : la dernière étape de la frise atteinte (« en négociation » et « paiement attendu » comptent comme prix proposé)
    final courant = switch (d.statut) {
      'EN_NEGOCIATION' || 'PAIEMENT_EN_ATTENTE' => 'PRIX_PROPOSE',
      'LITIGE' => 'LIVRE',
      final s => s,
    };
    final idx = ordre.indexOf(courant);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(children: [
        for (var i = 0; i < Statuts.etapes.length; i++)
          _EtapeLigne(
            titre: Statuts.etapes[i].$2,
            date: dates[Statuts.etapes[i].$1],
            sousTitre: i == idx ? _detail(d) : null,
            etat: i < idx ? 1 : (i == idx ? 2 : 0),
            derniere: i == Statuts.etapes.length - 1,
          ),
      ]),
    );
  }

  static String? _detail(Dossier d) => switch (d.statut) {
        'EN_ATTENTE' => 'Recherche d\'un représentant dans votre zone',
        'REPRESENTANT_ASSIGNE' => '${d.evaluation?['nom_representant'] ?? 'Le représentant'} va venir évaluer la marchandise',
        'EN_EVALUATION' => '${d.evaluation?['nom_representant'] ?? 'Le représentant'} est sur place',
        'PRIX_PROPOSE' => 'Consultez l\'estimation et répondez',
        'EN_NEGOCIATION' => 'Négociation en cours',
        'PAIEMENT_EN_ATTENTE' => 'Paiement en attente',
        'PAYE' => 'Paiement confirmé, enlèvement à venir',
        'EN_TRANSIT' => 'Marchandise en route',
        'LITIGE' => 'Litige en cours de traitement',
        _ => null,
      };
}

class _EtapeLigne extends StatelessWidget {
  const _EtapeLigne({required this.titre, this.date, this.sousTitre, required this.etat, required this.derniere});

  final String titre;
  final String? date;
  final String? sousTitre;
  final int etat; // 0 à venir, 1 faite, 2 en cours
  final bool derniere;

  @override
  Widget build(BuildContext context) {
    final couleur = etat == 0 ? TC.border : (etat == 1 ? TC.success : TC.primary);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: etat == 1 ? TC.success : TC.white,
              shape: BoxShape.circle,
              border: Border.all(color: couleur, width: etat == 2 ? 6 : 2),
            ),
            child: etat == 1 ? const Icon(Icons.check, size: 14, color: TC.white) : null,
          ),
          if (!derniere) Expanded(child: Container(width: 2, color: etat == 1 ? TC.success : TC.border)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titre, style: GoogleFonts.inter(fontSize: 15, fontWeight: etat == 0 ? FontWeight.w500 : FontWeight.w600, color: etat == 0 ? TC.muted : TC.ink)),
              if (sousTitre != null) Text(sousTitre!, style: TC.small.copyWith(color: TC.primary)),
              if (date != null && etat != 0) Text(dateHeure(date), style: TC.caption),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Carte « représentant / chauffeur » avec bouton d'appel.
class _PersonneCard extends StatelessWidget {
  const _PersonneCard({required this.nom, required this.role, this.telephone});

  final String? nom;
  final String role;
  final String? telephone;

  @override
  Widget build(BuildContext context) => Panel(
        child: Row(children: [
          Initials(nom),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role, style: TC.caption),
              Text(nom ?? '—', style: TC.strong),
            ]),
          ),
          if (telephone != null)
            SquareButton(icon: Icons.phone_outlined, tooltip: 'Appeler', onPressed: () => appeler(telephone!)),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------------------------- M09

/// M09 — Estimation reçue : prix, détail du calcul, transporteur, négociation.
class EstimationScreen extends StatefulWidget {
  const EstimationScreen({super.key, required this.demandeId});

  final String demandeId;

  @override
  State<EstimationScreen> createState() => _EstimationScreenState();
}

class _Estimation {
  _Estimation(this.dossier, this.grille, this.transporteur, this.messages);

  final Dossier dossier;
  final Map<String, dynamic> grille;
  final Map<String, dynamic> transporteur;
  final List<Map<String, dynamic>> messages;
}

class _EstimationScreenState extends State<EstimationScreen> {
  Future<_Estimation>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_Estimation> _load() async {
    final api = context.api;
    final d = await _chargerDossier(api, widget.demandeId);
    final devis = d.devis!;
    final r = await Future.wait([api.get(devis['grille'] as String), api.list('/api/message_negociations', query: {'devis': '/api/devis/${devis['id']}'})]);
    final grille = r[0] as Map<String, dynamic>;
    final transporteur = await api.get(grille['transporteur'] as String);
    return _Estimation(d, grille, transporteur, r[1] as List<Map<String, dynamic>>);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _negocier(_Estimation e) async {
    final prix = TextEditingController();
    final message = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Proposer un autre prix', style: TC.h3),
          const SizedBox(height: 4),
          Text('3 échanges maximum. Le transporteur peut accepter ou maintenir son prix.', style: TC.small),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Votre prix (FCFA)',
            child: TextField(controller: prix, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          ),
          const SizedBox(height: 12),
          LabeledField(label: 'Message', child: TextField(controller: message, maxLength: 200, maxLines: 2)),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer')),
        ]),
      ),
    );
    if (ok != true || !mounted) return;
    final p = int.tryParse(prix.text);
    if (p == null && message.text.trim().isEmpty) return;
    final envoye = await act(
      context,
      () => context.api.post('/api/message_negociations', {
        'devis': '/api/devis/${e.dossier.devis!['id']}',
        'emetteur': 'marchand',
        'prix_contre_offre': ?p,
        if (message.text.trim().isNotEmpty) 'message': message.text.trim(),
      }),
      success: 'Proposition envoyée au transporteur.',
    );
    if (envoye) _refresh();
  }

  Future<void> _refuser(_Estimation e) async {
    if (!await confirm(context, 'Refuser le prix', 'Votre demande sera proposée à un autre transporteur.', ok: 'Refuser', danger: true)) return;
    if (!mounted) return;
    if (await act(context, () => context.api.patch('/api/devis/${e.dossier.devis!['id']}', {'statut': 'refuse'}), success: 'Prix refusé.')) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Loader<_Estimation>(
            future: _future,
            onRetry: _refresh,
            builder: (e) {
              final devis = e.dossier.devis!;
              final dm = e.dossier.demande;
              final negociable = ['propose', 'en_negociation'].contains(devis['statut']);
              final nbMarchand = e.messages.where((m) => m['emetteur'] == 'marchand').length;
              return Column(children: [
                TopBar(title: 'Estimation reçue', subtitle: '${dm['numero']}'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: TC.primary, borderRadius: BorderRadius.circular(20)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Prix proposé', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFDCE6F2))),
                          const SizedBox(height: 4),
                          Text.rich(TextSpan(children: [
                            TextSpan(text: nombre(devis['prix_propose'] as num), style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, color: TC.white)),
                            TextSpan(text: '  FCFA', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: TC.white)),
                          ])),
                          const SizedBox(height: 14),
                          Row(children: [
                            _Chiffre('Délai', '${devis['delai_jours']} jour(s)'),
                            _Chiffre('Véhicule', '${devis['type_vehicule'] ?? '—'}'),
                            _Chiffre('Valable jusqu\'au', date(devis['date_expiration'])),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Panel(
                        child: Row(children: [
                          Initials(e.transporteur['raison_sociale'] as String?),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${e.transporteur['raison_sociale']}', style: TC.strong),
                              Text(
                                e.transporteur['note_moyenne'] == null
                                    ? 'Pas encore d\'avis'
                                    : '★ ${'${e.transporteur['note_moyenne']}'.replaceAll('.', ',')} · ${e.transporteur['nb_avis']} avis',
                                style: TC.small,
                              ),
                            ]),
                          ),
                          if (e.transporteur['statut'] == 'actif')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: TC.successBg, borderRadius: BorderRadius.circular(20)),
                              child: Text('Vérifié', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: TC.success)),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      Text('Détail du prix', style: TC.h3),
                      const SizedBox(height: 10),
                      _DetailPrix(demande: dm, evaluation: e.dossier.evaluation!, grille: e.grille, devis: devis),
                      if (e.messages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Négociation', style: TC.h3),
                        const SizedBox(height: 10),
                        for (final m in e.messages) _Bulle(m),
                      ],
                      const SizedBox(height: 12),
                      InfoBox(negociable
                          ? 'Négociation possible : ${3 - nbMarchand} échange(s) restant(s).'
                          : 'Ce devis n\'est plus négociable.'),
                    ]),
                  ),
                ),
                if (negociable)
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
                    decoration: const BoxDecoration(color: TC.white, border: Border(top: BorderSide(color: TC.border))),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      FilledButton(
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaiementScreen(dossier: e.dossier)));
                          _refresh();
                        },
                        child: const Text('Accepter et payer'),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: nbMarchand >= 3 ? null : () => _negocier(e), child: const Text('Négocier'))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _refuser(e),
                            style: OutlinedButton.styleFrom(foregroundColor: TC.error, side: const BorderSide(color: TC.error, width: 2)),
                            child: const Text('Refuser'),
                          ),
                        ),
                      ]),
                    ]),
                  ),
              ]);
            },
          ),
        ),
      );
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDCE6F2))),
          Text(valeur, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: TC.white), overflow: TextOverflow.ellipsis),
        ]),
      );
}

/// Détail recalculé depuis la grille du transporteur (même formule que la base) : transparence du prix.
class _DetailPrix extends StatelessWidget {
  const _DetailPrix({required this.demande, required this.evaluation, required this.grille, required this.devis});

  final Map<String, dynamic> demande, evaluation, grille, devis;

  @override
  Widget build(BuildContext context) {
    double n(Object? v) => v == null ? 0 : double.parse('$v');
    final distance = n(demande['distance_km']);
    final poids = evaluation['poids_reel'] != null ? n(evaluation['poids_reel']) : n(demande['poids_estime']);
    final coef = n((grille['coef_type_marchandise'] as Map?)?[demande['type_marchandise']] ?? 1);
    final express = demande['urgence'] == 'express' ? n(grille['supplement_express']) : 0.0;
    final base = n(grille['prix_base']);
    final km = distance * n(grille['tarif_km']);
    final kg = poids * n(grille['tarif_kg']);
    final majoration = (base + km + kg) * (coef - 1);
    final suggere = devis['prix_suggere'] as num;
    final propose = devis['prix_propose'] as num;
    final arrondi = suggere - (base + km + kg + majoration + express);

    Widget ligne(String label, num montant, {bool fort = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: fort ? TC.strong : TC.body.copyWith(color: TC.muted))),
            Text('${montant < 0 ? '−' : ''}${fcfa(montant.abs().round())}', style: fort ? TC.strong : TC.body),
          ]),
        );
    return Panel(
      child: Column(children: [
        ligne('Prix de base', base),
        ligne('Distance (${nombre(distance)} km)', km),
        ligne('Poids ${evaluation['poids_reel'] != null ? 'réel' : 'estimé'} (${nombre(poids)} kg)', kg),
        if (coef != 1) ligne('${Statuts.types[demande['type_marchandise']]} (×${'$coef'.replaceAll('.', ',')})', majoration),
        if (express > 0) ligne('Supplément express', express),
        if (arrondi.abs() >= 1) ligne('Arrondi', arrondi),
        const Divider(height: 18),
        ligne('Prix calculé', suggere, fort: propose == suggere),
        if (propose != suggere) ...[
          ligne('Ajustement du transporteur', propose - suggere),
          if (devis['justification'] != null)
            Align(alignment: Alignment.centerLeft, child: Text('« ${devis['justification']} »', style: TC.small.copyWith(fontStyle: FontStyle.italic))),
          const Divider(height: 18),
          ligne('Total', propose, fort: true),
        ],
      ]),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle(this.m);

  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final moi = m['emetteur'] == 'marchand';
    return Align(
      alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(color: moi ? TC.primary100 : TC.white, borderRadius: BorderRadius.circular(14), boxShadow: TC.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moi ? 'Vous' : 'Transporteur', style: TC.caption),
          if (m['prix_contre_offre'] != null) Text(fcfa(m['prix_contre_offre']), style: TC.strong),
          if (m['message'] != null) Text('${m['message']}', style: TC.body.copyWith(fontSize: 14)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------- M10

const _operateurs = {'MTN': 'MTN', 'Moov': 'Moov', 'Wave': 'Wave', 'Orange': 'Orange'};

/// M10 — Paiement.
class PaiementScreen extends StatefulWidget {
  const PaiementScreen({super.key, required this.dossier});

  final Dossier dossier;

  @override
  State<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends State<PaiementScreen> {
  String _moyen = 'mobile_money';
  String _operateur = 'MTN';
  late final _numero = TextEditingController(text: context.session.me?['telephone'] as String? ?? '');
  bool _busy = false;

  Future<void> _payer() async {
    final devis = widget.dossier.devis!;
    setState(() => _busy = true);
    try {
      final p = await context.api.post('/api/paiements', {
        'devis': '/api/devis/${devis['id']}',
        'montant': devis['prix_propose'],
        'moyen': _moyen,
        if (_moyen == 'mobile_money') 'operateur': _operateur,
        if (_moyen == 'mobile_money') 'numero_payeur': _numero.text.replaceAll(' ', ''),
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PaiementEnvoyeScreen(paiement: p, dossier: widget.dossier)));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devis = widget.dossier.devis!;
    final dm = widget.dossier.demande;
    Widget moyen(String id, IconData icon, String titre, String detail) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: TC.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TC.radius),
              side: BorderSide(color: _moyen == id ? TC.primary : TC.border, width: _moyen == id ? 2 : 1.5),
            ),
            child: RadioListTile<String>(
              value: id,
              // ignore: deprecated_member_use
              groupValue: _moyen,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _moyen = v!),
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: Icon(icon, color: TC.primary),
              title: Text(titre, style: TC.strong),
              subtitle: Text(detail, style: TC.small),
            ),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'Paiement'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
              Panel(
                child: Column(children: [
                  Text('Montant à payer', style: TC.small),
                  const SizedBox(height: 4),
                  Text(fcfa(devis['prix_propose']).replaceAll(' F', ' FCFA'), style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w700, color: TC.ink)),
                  Text('${dm['numero']} · ${dm['nom_ville_depart']} → ${dm['nom_ville_arrivee']}', style: TC.small, textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 18),
              Text('Moyen de paiement', style: TC.h3),
              const SizedBox(height: 10),
              moyen('mobile_money', Icons.phone_android, 'Mobile Money', 'MTN, Moov, Wave, Orange'),
              moyen('carte', Icons.credit_card, 'Carte bancaire', 'Visa, Mastercard'),
              moyen('virement', Icons.account_balance_outlined, 'Virement', 'Validation sous 24 à 48 h'),
              if (_moyen == 'mobile_money') ...[
                const SizedBox(height: 8),
                Text('Opérateur', style: TC.label),
                const SizedBox(height: 8),
                ChoiceGrid(options: _operateurs, value: _operateur, columns: 4, onChanged: (v) => setState(() => _operateur = v)),
                const SizedBox(height: 14),
                LabeledField(label: 'Numéro Mobile Money', child: TextField(controller: _numero, keyboardType: TextInputType.phone)),
              ],
              const SizedBox(height: 16),
              const InfoBox('Paiement sécurisé. Les fonds restent bloqués jusqu\'à la confirmation de livraison.', icon: Icons.lock_outline),
            ]),
          ),
          BottomActions(children: [
            FilledButton(
              onPressed: _busy ? null : _payer,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: TC.white))
                  : Text('Payer ${fcfa(devis['prix_propose']).replaceAll(' F', ' FCFA')}'),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// M11 — Paiement envoyé : en attente de la confirmation de l'opérateur (statut « initié »).
class PaiementEnvoyeScreen extends StatelessWidget {
  const PaiementEnvoyeScreen({super.key, required this.paiement, required this.dossier});

  final Map<String, dynamic> paiement;
  final Dossier dossier;

  @override
  Widget build(BuildContext context) {
    final reussi = paiement['statut'] == 'reussi';
    final moyen = switch (paiement['moyen']) {
      'mobile_money' => '${paiement['operateur']} Mobile Money',
      'carte' => 'Carte bancaire',
      _ => 'Virement',
    };
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 48, 24, 24), children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(color: reussi ? TC.successBg : TC.primary100, shape: BoxShape.circle),
                  child: Icon(reussi ? Icons.check : Icons.hourglass_top, size: 44, color: reussi ? TC.success : TC.primary),
                ),
              ),
              const SizedBox(height: 20),
              Text(reussi ? 'Paiement confirmé' : 'Paiement en cours de confirmation', textAlign: TextAlign.center, style: TC.h1.copyWith(fontSize: 24)),
              const SizedBox(height: 10),
              Text(
                reussi
                    ? 'Votre commande ${dossier.demande['numero']} est validée. Le transporteur vous contactera pour l\'enlèvement.'
                    : 'Validez le paiement sur votre téléphone si votre opérateur vous le demande. Votre commande ${dossier.demande['numero']} sera validée dès la confirmation, et vous serez prévenu.',
                textAlign: TextAlign.center,
                style: TC.bodyMuted,
              ),
              const SizedBox(height: 24),
              Panel(
                child: Column(children: [
                  _Ligne('Montant', fcfa(paiement['montant']).replaceAll(' F', ' FCFA')),
                  _Ligne('Moyen', moyen),
                  _Ligne('Référence', '${paiement['reference_psp'] ?? (paiement['id'] as String).substring(0, 8).toUpperCase()}'),
                  _Ligne('Statut', reussi ? 'Confirmé' : 'En attente de confirmation'),
                ]),
              ),
              const SizedBox(height: 12),
              const InfoBox('Les fonds restent bloqués jusqu\'à la confirmation de livraison avec votre code de réception.', icon: Icons.lock_outline),
            ]),
          ),
          BottomActions(children: [
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour au suivi')),
          ]),
        ]),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: TC.bodyMuted)),
          Flexible(child: Text(valeur, style: TC.strong, textAlign: TextAlign.right)),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------------------------- M12

/// M12 — Suivi de la livraison : carte, chauffeur, code de réception.
class SuiviCarteScreen extends StatefulWidget {
  const SuiviCarteScreen({super.key, required this.demandeId});

  final String demandeId;

  @override
  State<SuiviCarteScreen> createState() => _SuiviCarteScreenState();
}

class _SuiviCarteScreenState extends State<SuiviCarteScreen> {
  Future<(Dossier, List<Map<String, dynamic>>)>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(Dossier, List<Map<String, dynamic>>)> _load() async {
    final api = context.api;
    final d = await _chargerDossier(api, widget.demandeId);
    final positions = d.livraison == null
        ? <Map<String, dynamic>>[]
        : await api.list('/api/position_gps', query: {'livraison': '/api/livraisons/${d.livraison!['id']}'});
    return (d, positions);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Loader<(Dossier, List<Map<String, dynamic>>)>(
            future: _future,
            onRetry: _refresh,
            builder: (data) {
              final (d, positions) = data;
              final lv = d.livraison;
              final session = context.session;
              LatLng? point(Map<String, dynamic>? v) =>
                  v == null || v['latitude'] == null ? null : LatLng(double.parse('${v['latitude']}'), double.parse('${v['longitude']}'));
              final depart = point(session.ville(d.demande['ville_depart'] as String?));
              final arrivee = point(session.ville(d.demande['ville_arrivee'] as String?));
              // Ordre chronologique par numéro de position (fiable même si deux relevés ont la même heure)
              final ordonnees = [...positions]..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
              final trace = [for (final p in ordonnees) LatLng(double.parse('${p['latitude']}'), double.parse('${p['longitude']}'))];
              final camion = trace.isEmpty ? null : trace.last;
              final pts = [?depart, ?arrivee, ...trace];
              return Column(children: [
                TopBar(title: 'Suivi en direct', subtitle: '${d.demande['numero']}', trailing: SquareButton(icon: Icons.refresh, tooltip: 'Actualiser', onPressed: _refresh)),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
                    if (pts.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 300,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCameraFit: pts.length > 1
                                  ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(36))
                                  : null,
                              initialCenter: pts.first,
                              initialZoom: 9,
                            ),
                            children: [
                              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 're.teranga.transportconnect'),
                              if (depart != null && arrivee != null)
                                PolylineLayer(polylines: [Polyline(points: [depart, ...trace, arrivee], color: TC.primary, strokeWidth: 4)]),
                              MarkerLayer(markers: [
                                if (depart != null) Marker(point: depart, width: 28, height: 28, child: const Icon(Icons.radio_button_checked, color: TC.primary)),
                                if (arrivee != null) Marker(point: arrivee, width: 34, height: 34, child: const Icon(Icons.location_on, color: TC.secondary, size: 34)),
                                if (camion != null)
                                  Marker(
                                    point: camion,
                                    width: 40,
                                    height: 40,
                                    child: Container(
                                      decoration: const BoxDecoration(color: TC.primary, shape: BoxShape.circle),
                                      child: const Icon(Icons.local_shipping, color: TC.white, size: 22),
                                    ),
                                  ),
                              ]),
                              const RichAttributionWidget(attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')]),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Panel(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lv?['date_arrivee_estimee'] != null ? 'Arrivée estimée : ${date(lv!['date_arrivee_estimee'])}' : 'Arrivée à confirmer', style: TC.strong),
                            Text(
                              camion != null ? 'Dernière position : ${dateHeure(ordonnees.last['horodatage'])}' : '${d.demande['nom_ville_depart']} → ${d.demande['nom_ville_arrivee']}',
                              style: TC.small,
                            ),
                          ]),
                        ),
                        StatusBadge(d.statut),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (lv == null)
                      const InfoBox('Le transporteur prépare l\'enlèvement. Le chauffeur et votre code de réception apparaîtront ici.', icon: Icons.schedule)
                    else ...[
                      if (lv['nom_chauffeur'] != null)
                        _PersonneCard(nom: lv['nom_chauffeur'] as String?, role: 'Chauffeur · ${lv['description_vehicule'] ?? ''}', telephone: lv['telephone_chauffeur'] as String?),
                      const SizedBox(height: 12),
                      if (lv['code_clair'] != null && d.statut != 'LIVRE')
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: TC.secondary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: TC.secondary)),
                          child: Column(children: [
                            Text('Code de réception', style: TC.strong),
                            Text('À donner au chauffeur à la livraison, pas avant', style: TC.small),
                            const SizedBox(height: 10),
                            Text((lv['code_clair'] as String).split('').join('  '),
                                style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 4, color: TC.ink)),
                          ]),
                        )
                      else if (d.statut == 'LIVRE')
                        InfoBox('Livraison confirmée le ${dateHeure(lv['date_livraison'])}.', icon: Icons.check_circle_outline),
                    ],
                  ]),
                ),
              ]);
            },
          ),
        ),
      );
}
