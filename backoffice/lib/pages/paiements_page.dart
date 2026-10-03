import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/resource_table.dart';

/// Paiements et séquestre : confirmation (en attendant le webhook PSP), libération des fonds, remboursement.
class PaiementsPage extends StatefulWidget {
  const PaiementsPage({super.key});

  @override
  State<PaiementsPage> createState() => _PaiementsPageState();
}

class _PaiementsPageState extends State<PaiementsPage> {
  final _table = GlobalKey<ResourceTableState>();
  String? _statut;
  String? _sequestre;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader('Paiements', subtitle: 'Transactions, séquestre et commissions'),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilterDropdown(
              label: 'Statut',
              value: _statut,
              options: {for (final e in Statuts.paiement.entries) e.key: e.value.$1},
              onChanged: (v) => setState(() => _statut = v),
            ),
            FilterDropdown(
              label: 'Séquestre',
              value: _sequestre,
              options: {for (final e in Statuts.sequestre.entries) e.key: e.value.$1},
              onChanged: (v) => setState(() => _sequestre = v),
            ),
          ]),
          const SizedBox(height: 16),
          ResourceTable(
            key: _table,
            path: '/api/paiements',
            query: {'statut': _statut ?? '', 'statut_sequestre': _sequestre ?? ''},
            columns: [
              TableColumn('Référence', (r) => cellText(r['reference_psp'] ?? '—', bold: true), flex: 2),
              TableColumn('Demande', (r) => cellText(r['numero_demande']), flex: 2),
              TableColumn('Marchand', (r) => cellText(r['nom_marchand']), flex: 2),
              TableColumn('Montant', (r) => cellText(fcfa(r['montant'])), flex: 2),
              TableColumn('Moyen', (r) => cellText(r['operateur'] ?? _moyens[r['moyen']]), flex: 2),
              TableColumn('Statut', (r) => StatusBadge(r['statut'] as String?, Statuts.paiement), flex: 2),
              TableColumn('Séquestre', (r) => StatusBadge(r['statut_sequestre'] as String?, Statuts.sequestre), flex: 2),
              TableColumn('Date', (r) => cellText(date(r['date_paiement'] ?? r['created_at'])), flex: 2),
            ],
            onTap: (row) async {
              await showDialog(context: context, builder: (_) => _PaiementDetail(row));
              _table.currentState?.reload();
            },
          ),
        ],
      );
}

const _moyens = {'mobile_money': 'Mobile Money', 'carte': 'Carte', 'virement': 'Virement'};

class _PaiementDetail extends StatefulWidget {
  const _PaiementDetail(this.paiement);

  final Map<String, dynamic> paiement;

  @override
  State<_PaiementDetail> createState() => _PaiementDetailState();
}

class _PaiementDetailState extends State<_PaiementDetail> {
  late Map<String, dynamic> p = widget.paiement;

  Future<void> _action(String titre, String message, Map<String, dynamic> body, String success, {bool danger = false}) async {
    if (!await confirm(context, titre, message, confirmLabel: titre, danger: danger) || !mounted) return;
    await runAction(context, () async {
      final r = await context.api.patch(p['@id'] as String, body);
      setState(() => p = r);
    }, success: success);
  }

  @override
  Widget build(BuildContext context) {
    final statut = p['statut'];
    final sequestre = p['statut_sequestre'];
    final montant = p['montant'] as num;
    final commission = (p['montant_commission'] as num?) ?? 0;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(fcfa(montant), style: TC.h1)),
              StatusBadge(statut as String?, Statuts.paiement),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            Text('Demande ${p['numero_demande']} — ${p['nom_marchand']}', style: TC.body.copyWith(color: TC.gray500)),
            const Divider(height: 32),
            InfoRow('Référence PSP', p['reference_psp']),
            InfoRow('Moyen', '${_moyens[p['moyen']]}${p['operateur'] != null ? ' · ${p['operateur']}' : ''}'),
            InfoRow('Payeur', p['numero_payeur']),
            InfoRow('Séquestre', StatusBadge(sequestre as String?, Statuts.sequestre)),
            InfoRow('Commission (${p['taux_commission']} %)', fcfa(commission)),
            InfoRow('Net transporteur', fcfa(montant - commission)),
            InfoRow('Payé le', dateHeure(p['date_paiement'])),
            InfoRow('Libéré le', dateHeure(p['date_liberation'])),
            if (p['motif_echec'] != null) InfoRow("Motif d'échec", p['motif_echec']),
            InfoRow('Reçu', p['url_recu']),
            const SizedBox(height: 24),
            Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 8, children: [
              if (statut == 'initie' || statut == 'en_cours') ...[
                OutlinedButton(
                  onPressed: () => _action('Marquer échoué', 'Le paiement sera marqué comme échoué.',
                      {'statut': 'echoue'}, 'Paiement marqué échoué.', danger: true),
                  child: const Text('Marquer échoué'),
                ),
                FilledButton(
                  onPressed: () => _action('Confirmer', 'À utiliser si le PSP a confirmé le paiement sans webhook. '
                      'Les fonds passeront en séquestre et la demande en PAYÉ.', {'statut': 'reussi'}, 'Paiement confirmé.'),
                  child: const Text('Confirmer le paiement'),
                ),
              ],
              if (statut == 'reussi' && sequestre == 'bloque') ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: TC.error, side: const BorderSide(color: TC.error, width: 2)),
                  onPressed: () => _action('Rembourser', 'Le marchand sera remboursé intégralement (${fcfa(montant)}).',
                      {'statut': 'rembourse', 'statut_sequestre': 'rembourse_total'}, 'Remboursement enregistré.', danger: true),
                  child: const Text('Rembourser'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: TC.success),
                  onPressed: () => _action('Libérer les fonds',
                      '${fcfa(montant - commission)} seront versés au transporteur (commission ${fcfa(commission)}).',
                      {'statut_sequestre': 'libere'}, 'Fonds libérés.'),
                  child: const Text('Libérer les fonds'),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
