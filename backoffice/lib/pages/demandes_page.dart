import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/resource_table.dart';

/// Colonnes du tableau des demandes ; `compact` = tableau « Demandes récentes » de la maquette.
List<TableColumn> demandeColumns({bool compact = false}) => [
      TableColumn(compact ? 'ID' : 'N°', (r) => cellText(r['numero'], bold: true), flex: 2),
      TableColumn('Trajet', (r) => cellText('${r['ville_depart']} → ${r['ville_arrivee']}'), flex: 3),
      TableColumn('Marchand', (r) => Text('${r['marchand'] ?? '—'}', overflow: TextOverflow.ellipsis, style: TC.muted), flex: 2),
      if (!compact) TableColumn('Transporteur', (r) => cellText(r['transporteur']), flex: 2),
      TableColumn('Statut', (r) => StatusBadge(r['statut'] as String?, Statuts.demande), flex: 2),
      TableColumn('Montant', (r) => cellText(r['prix_propose'] == null ? '—' : fcfa(r['prix_propose']), bold: true),
          flex: 2, alignRight: true),
      if (!compact) TableColumn('Créée le', (r) => cellText(date(r['created_at'])), flex: 2),
    ];

/// Suivi de toutes les demandes (vue v_suivi_demande).
class DemandesPage extends StatefulWidget {
  const DemandesPage({super.key, this.numero});

  final String? numero;

  @override
  State<DemandesPage> createState() => _DemandesPageState();
}

class _DemandesPageState extends State<DemandesPage> {
  String? _statut;
  late String _numero = widget.numero ?? '';
  String _marchand = '';

  @override
  void didUpdateWidget(DemandesPage old) {
    super.didUpdateWidget(old);
    if (old.numero != widget.numero) _numero = widget.numero ?? '';
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader('Demandes', subtitle: 'Suivi de toutes les demandes de transport'),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilterDropdown(
              label: 'Statut',
              value: _statut,
              options: {for (final e in Statuts.demande.entries) e.key: e.value.$1},
              onChanged: (v) => setState(() => _statut = v),
            ),
            SearchField(
              key: ValueKey('numero-$_numero'),
              hint: _numero.isEmpty ? 'N° de demande' : _numero,
              onSubmitted: (v) => setState(() => _numero = v.trim()),
            ),
            SearchField(hint: 'Marchand', onSubmitted: (v) => setState(() => _marchand = v.trim())),
            if (_numero.isNotEmpty)
              InputChip(
                label: Text('N° contient « $_numero »'),
                onDeleted: () {
                  setState(() => _numero = '');
                  context.go('/demandes');
                },
              ),
          ]),
          const SizedBox(height: 16),
          ResourceTable(
            path: '/api/suivi_demandes',
            query: {'statut': _statut ?? '', 'numero': _numero, 'marchand': _marchand},
            columns: demandeColumns(),
            onTap: (row) => showDemandeDetail(context, row),
            emptyMessage: 'Aucune demande ne correspond aux filtres.',
          ),
        ],
      );
}

/// Fiche d'une demande : informations, acteurs, devis / paiement / livraison et historique des statuts.
Future<void> showDemandeDetail(BuildContext context, Map<String, dynamic> suivi) =>
    showDialog(context: context, builder: (_) => _DemandeDetail(suivi: suivi));

class _DemandeDetail extends StatelessWidget {
  const _DemandeDetail({required this.suivi});

  final Map<String, dynamic> suivi;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    final id = suivi['id'] as String;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: FutureBuilder(
            future: Future.wait([
              api.get('/api/demandes/$id'),
              api.list('/api/historique_statuts', query: {'demande': '/api/demandes/$id'}),
            ]),
            builder: (context, snapshot) {
              if (snapshot.hasError) return ErrorBox('${snapshot.error}');
              if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              final d = snapshot.data![0] as Map<String, dynamic>;
              final historique = (snapshot.data![1] as dynamic).items as List<Map<String, dynamic>>;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('${suivi['numero']}', style: TC.h2)),
                    StatusBadge(suivi['statut'] as String?, Statuts.demande),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ]),
                  Text('${suivi['ville_depart']} → ${suivi['ville_arrivee']}', style: TC.body.copyWith(color: TC.gray500)),
                  const Divider(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(spacing: 32, runSpacing: 16, children: [
                        SizedBox(
                          width: 400,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Marchandise', style: TC.h3),
                            InfoRow('Type', d['type_marchandise']),
                            InfoRow('Description', d['description']),
                            InfoRow('Poids / volume', '${d['poids_estime'] ?? '—'} kg · ${d['volume_estime'] ?? '—'} m³'),
                            InfoRow('Urgence', d['urgence']),
                            InfoRow('Enlèvement', '${date(d['date_enlevement'])} — ${d['adresse_depart']}'),
                            InfoRow('Livraison', d['adresse_arrivee']),
                            InfoRow('Distance', d['distance_km'] == null ? null : '${d['distance_km']} km'),
                            const SizedBox(height: 16),
                            Text('Acteurs', style: TC.h3),
                            InfoRow('Marchand', suivi['marchand']),
                            InfoRow('Contact sur place', d['contact_nom'] == null ? null : '${d['contact_nom']} ${d['contact_telephone'] ?? ''}'),
                            InfoRow('Représentant', suivi['representant']),
                            InfoRow('Transporteur', suivi['transporteur']),
                            const SizedBox(height: 16),
                            Text('Devis, paiement, livraison', style: TC.h3),
                            InfoRow('Prix proposé', suivi['prix_propose'] == null ? null : fcfa(suivi['prix_propose'])),
                            InfoRow('Délai', suivi['delai_jours'] == null ? null : '${suivi['delai_jours']} jour(s)'),
                            InfoRow('Statut devis', suivi['statut_devis']),
                            InfoRow('Paiement', StatusBadge(suivi['statut_paiement'] as String?, Statuts.paiement)),
                            InfoRow('Séquestre', StatusBadge(suivi['statut_sequestre'] as String?, Statuts.sequestre)),
                            InfoRow('Livraison', suivi['statut_livraison']),
                            InfoRow('Arrivée estimée', suivi['date_arrivee_estimee'] == null ? null : date(suivi['date_arrivee_estimee'])),
                          ]),
                        ),
                        SizedBox(
                          width: 240,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Historique', style: TC.h3),
                            const SizedBox(height: 8),
                            for (final h in historique) _TimelineItem(h),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem(this.h);

  final Map<String, dynamic> h;

  @override
  Widget build(BuildContext context) {
    final (label, color) = Statuts.demande[h['nouveau_statut']] ?? ('${h['nouveau_statut']}', TC.gray500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 12, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TC.label.copyWith(color: TC.gray900)),
            Text(dateHeure(h['date_changement']), style: TC.caption),
          ]),
        ),
      ]),
    );
  }
}
