import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/resource_table.dart';

/// Compagnies de transport : validation, suspension, flotte, grille tarifaire et équipe.
class TransporteursPage extends StatefulWidget {
  const TransporteursPage({super.key});

  @override
  State<TransporteursPage> createState() => _TransporteursPageState();
}

class _TransporteursPageState extends State<TransporteursPage> {
  final _table = GlobalKey<ResourceTableState>();
  String? _statut;
  String _nom = '';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader('Transporteurs', subtitle: 'Compagnies partenaires', actions: [
            FilledButton.icon(
              onPressed: () async {
                if (await showDialog<bool>(context: context, builder: (_) => const _TransporteurForm()) ?? false) {
                  _table.currentState?.reload();
                }
              },
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Nouveau transporteur'),
            ),
          ]),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilterDropdown(
              label: 'Statut',
              value: _statut,
              options: {for (final e in Statuts.compte.entries) e.key: e.value.$1},
              onChanged: (v) => setState(() => _statut = v),
            ),
            SearchField(hint: 'Raison sociale', onSubmitted: (v) => setState(() => _nom = v.trim())),
          ]),
          const SizedBox(height: 16),
          ResourceTable(
            key: _table,
            path: '/api/transporteurs',
            query: {'statut': _statut ?? '', 'raison_sociale': _nom},
            columns: [
              TableColumn('Raison sociale', (r) => cellText(r['raison_sociale'], bold: true), flex: 3),
              TableColumn('RCCM', (r) => cellText(r['num_rccm']), flex: 2),
              TableColumn('Téléphone', (r) => cellText(r['telephone']), flex: 2),
              TableColumn('Abonnement', (r) => cellText(r['abonnement'] == 'premium' ? 'Premium' : 'Gratuit')),
              TableColumn('Note', (r) => cellText(r['note_moyenne'] == null ? null : '★ ${r['note_moyenne']} (${r['nb_avis']})')),
              TableColumn('Statut', (r) => StatusBadge(r['statut'] as String?, Statuts.compte), flex: 2),
            ],
            onTap: (row) async {
              await showDialog(context: context, builder: (_) => _TransporteurDetail(row));
              _table.currentState?.reload();
            },
          ),
        ],
      );
}

class _TransporteurDetail extends StatefulWidget {
  const _TransporteurDetail(this.transporteur);

  final Map<String, dynamic> transporteur;

  @override
  State<_TransporteurDetail> createState() => _TransporteurDetailState();
}

class _TransporteurDetailState extends State<_TransporteurDetail> {
  late Map<String, dynamic> t = widget.transporteur;
  late final Future<List<ApiPage>> _liens = Future.wait([
    context.api.list('/api/vehicules', query: {'transporteur': t['@id'] as String}),
    context.api.list('/api/grille_tarifaires', query: {'transporteur': t['@id'] as String, 'actif': 'true'}),
    context.api.list('/api/utilisateurs', query: {'transporteur': t['@id'] as String}),
  ]);

  Future<void> _patch(Map<String, dynamic> body, String success) => runAction(context, () async {
        final r = await context.api.patch(t['@id'] as String, body);
        setState(() => t = r);
      }, success: success);

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${t['raison_sociale']}', style: TC.h2)),
                StatusBadge(t['statut'] as String?, Statuts.compte),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const Divider(height: 32),
              InfoRow('RCCM', t['num_rccm']),
              InfoRow('Téléphone', t['telephone']),
              InfoRow('Abonnement', t['abonnement']),
              InfoRow('Note', t['note_moyenne'] == null ? null : '★ ${t['note_moyenne']} (${t['nb_avis']} avis)'),
              InfoRow('Partenaire depuis', date(t['created_at'])),
              FutureBuilder<List<ApiPage>>(
                future: _liens,
                builder: (context, s) {
                  if (s.hasError) return ErrorBox('${s.error}');
                  if (!s.hasData) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
                  final [vehicules, grilles, equipe] = s.data!;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 16),
                    Text('Flotte (${vehicules.total})', style: TC.h3),
                    for (final v in vehicules.items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text('${v['type_vehicule']} — ${v['immatriculation']}'),
                        subtitle: Text('${nombre(v['capacite_kg'] as num)} kg'
                            '${v['capacite_m3'] != null ? ' · ${v['capacite_m3']} m³' : ''}'
                            '${v['gps_actif'] == true ? ' · GPS' : ''}'),
                      ),
                    const SizedBox(height: 16),
                    Text('Grille tarifaire', style: TC.h3),
                    if (grilles.items.isEmpty) Text('Aucune grille active.', style: TC.caption),
                    for (final g in grilles.items) ...[
                      InfoRow('Prix de base', fcfa(g['prix_base'])),
                      InfoRow('Tarif / km', '${g['tarif_km']} F'),
                      InfoRow('Tarif / kg', '${g['tarif_kg']} F'),
                      InfoRow('Supplément express', fcfa(g['supplement_express'])),
                      InfoRow('En vigueur depuis', date(g['date_effet'])),
                    ],
                    const SizedBox(height: 16),
                    Text('Équipe (${equipe.total})', style: TC.h3),
                    for (final u in equipe.items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text('${u['nom_complet']}'),
                        subtitle: Text('${Statuts.roles[u['role']]} · ${u['telephone']}'),
                        trailing: StatusBadge(u['statut_compte'] as String?, Statuts.compte),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 24),
              Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 8, children: [
                OutlinedButton(
                  onPressed: () => _patch({'abonnement': t['abonnement'] == 'premium' ? 'gratuit' : 'premium'}, 'Abonnement modifié.'),
                  child: Text(t['abonnement'] == 'premium' ? 'Passer en gratuit' : 'Passer en premium'),
                ),
                if (t['statut'] != 'actif')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: TC.success),
                    onPressed: () => _patch({'statut': 'actif'}, 'Transporteur validé.'),
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(t['statut'] == 'suspendu' ? 'Réactiver' : 'Valider'),
                  ),
                if (t['statut'] != 'suspendu')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: TC.error),
                    onPressed: () async {
                      if (await confirm(context, 'Suspendre le transporteur',
                          'Ses représentants ne recevront plus de missions.', confirmLabel: 'Suspendre', danger: true)) {
                        await _patch({'statut': 'suspendu'}, 'Transporteur suspendu.');
                      }
                    },
                    icon: const Icon(Icons.block),
                    label: const Text('Suspendre'),
                  ),
              ]),
            ]),
          ),
        ),
      );
}

class _TransporteurForm extends StatefulWidget {
  const _TransporteurForm();

  @override
  State<_TransporteurForm> createState() => _TransporteurFormState();
}

class _TransporteurFormState extends State<_TransporteurForm> {
  final _nom = TextEditingController();
  final _rccm = TextEditingController();
  final _tel = TextEditingController(text: '+229');
  String? _error;

  Future<void> _save() async {
    try {
      await context.api.post('/api/transporteurs', {
        'raison_sociale': _nom.text.trim(),
        'num_rccm': _rccm.text.trim(),
        'telephone': _tel.text.replaceAll(' ', ''),
        'statut': 'actif',
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Nouveau transporteur', style: TC.h3),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Raison sociale')),
            const SizedBox(height: 12),
            TextField(controller: _rccm, decoration: const InputDecoration(labelText: 'N° RCCM')),
            const SizedBox(height: 12),
            TextField(controller: _tel, decoration: const InputDecoration(labelText: 'Téléphone')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: TC.error))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: _save, child: const Text('Créer')),
        ],
      );
}
