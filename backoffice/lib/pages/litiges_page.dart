import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/resource_table.dart';

const _motifs = {
  'colis_endommage': 'Colis endommagé',
  'colis_manquant': 'Colis manquant',
  'non_livre': 'Non livré',
  'autre': 'Autre',
};

const _decisions = {
  'remboursement_total': 'Remboursement total',
  'remboursement_partiel': 'Remboursement partiel',
  'liberation_transporteur': 'Libération au transporteur',
};

/// Modération des litiges : prise en charge et décision.
class LitigesPage extends StatefulWidget {
  const LitigesPage({super.key});

  @override
  State<LitigesPage> createState() => _LitigesPageState();
}

class _LitigesPageState extends State<LitigesPage> {
  final _table = GlobalKey<ResourceTableState>();
  String? _statut;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader('Litiges', subtitle: 'Contestations à arbitrer'),
          Wrap(children: [
            FilterDropdown(
              label: 'Statut',
              value: _statut,
              options: {for (final e in Statuts.litige.entries) e.key: e.value.$1},
              onChanged: (v) => setState(() => _statut = v),
            ),
          ]),
          const SizedBox(height: 16),
          ResourceTable(
            key: _table,
            path: '/api/litiges',
            query: {'statut': _statut ?? ''},
            emptyMessage: 'Aucun litige. 🎉',
            columns: [
              TableColumn('Demande', (r) => cellText(r['numero_demande'], bold: true), flex: 2),
              TableColumn('Motif', (r) => cellText(_motifs[r['motif']]), flex: 2),
              TableColumn('Ouvert par', (r) => cellText(r['nom_ouvreur']), flex: 2),
              TableColumn('Description', (r) => cellText(r['description']), flex: 4),
              TableColumn('Statut', (r) => StatusBadge(r['statut'] as String?, Statuts.litige), flex: 2),
              TableColumn('Ouvert le', (r) => cellText(date(r['date_ouverture'])), flex: 2),
            ],
            onTap: (row) async {
              await showDialog(context: context, builder: (_) => _LitigeDetail(row));
              _table.currentState?.reload();
            },
          ),
        ],
      );
}

class _LitigeDetail extends StatefulWidget {
  const _LitigeDetail(this.litige);

  final Map<String, dynamic> litige;

  @override
  State<_LitigeDetail> createState() => _LitigeDetailState();
}

class _LitigeDetailState extends State<_LitigeDetail> {
  late Map<String, dynamic> l = widget.litige;
  String _decision = 'remboursement_total';
  final _montant = TextEditingController();
  String? _error;

  Future<void> _patch(Map<String, dynamic> body, String success) async {
    setState(() => _error = null);
    try {
      final r = await context.api.patch(l['@id'] as String, body);
      setState(() => l = r);
      if (mounted) toast(context, success);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolu = l['statut'] == 'resolu';
    final admin = AuthScope.of(context).userIri;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Litige — ${l['numero_demande']}', style: TC.h2)),
              StatusBadge(l['statut'] as String?, Statuts.litige),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const Divider(height: 32),
            InfoRow('Motif', _motifs[l['motif']]),
            InfoRow('Ouvert par', l['nom_ouvreur']),
            InfoRow('Ouvert le', dateHeure(l['date_ouverture'])),
            InfoRow('Description', l['description']),
            if (resolu) ...[
              InfoRow('Décision', _decisions[l['decision']]),
              if (l['montant_rembourse'] != null) InfoRow('Montant remboursé', fcfa(l['montant_rembourse'])),
              InfoRow('Résolu le', dateHeure(l['date_resolution'])),
            ] else ...[
              const SizedBox(height: 20),
              Text('Décision', style: TC.h3),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _decision,
                onChanged: (v) => setState(() => _decision = v!),
                child: Column(children: [
                  for (final e in _decisions.entries)
                    RadioListTile<String>(value: e.key, title: Text(e.value), contentPadding: EdgeInsets.zero),
                ]),
              ),
              if (_decision == 'remboursement_partiel')
                TextField(
                  controller: _montant,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Montant remboursé (FCFA)'),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Pensez à appliquer la décision sur le paiement (remboursement ou libération) depuis la page Paiements.',
                  style: TC.caption,
                ),
              ),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: TC.error))),
            if (!resolu) ...[
              const SizedBox(height: 24),
              Wrap(alignment: WrapAlignment.end, spacing: 12, children: [
                if (l['statut'] == 'ouvert')
                  OutlinedButton(
                    onPressed: () => _patch({'statut': 'en_cours', 'admin': admin}, 'Litige pris en charge.'),
                    child: const Text('Prendre en charge'),
                  ),
                FilledButton(
                  onPressed: _decision == 'remboursement_partiel' && (int.tryParse(_montant.text.replaceAll(' ', '')) ?? 0) <= 0
                      ? null
                      : () => _patch({
                    'statut': 'resolu',
                    'decision': _decision,
                    'admin': admin,
                    'date_resolution': DateTime.now().toUtc().toIso8601String(),
                    'montant_rembourse': _decision == 'remboursement_partiel' ? int.tryParse(_montant.text.replaceAll(' ', '')) : null,
                  }, 'Litige résolu.'),
                  child: const Text('Rendre la décision'),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
