import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/resource_table.dart';

/// Paramétrage : villes et zones couvertes par la plateforme.
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _table = GlobalKey<ResourceTableState>();

  Future<void> _toggle(Map<String, dynamic> ville, bool couverte) async {
    if (await runAction(context, () => context.api.patch(ville['@id'] as String, {'est_couverte': couverte}),
        success: couverte ? '${ville['nom_ville']} est desservie.' : "${ville['nom_ville']} n'est plus desservie.")) {
      _table.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader('Configuration', subtitle: 'Villes et zones couvertes', actions: [
            FilledButton.icon(
              onPressed: () async {
                if (await showDialog<bool>(context: context, builder: (_) => const _VilleForm()) ?? false) {
                  _table.currentState?.reload();
                }
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Ajouter une ville'),
            ),
          ]),
          ResourceTable(
            key: _table,
            path: '/api/villes',
            columns: [
              TableColumn('Ville', (r) => cellText(r['nom_ville'], bold: true), flex: 3),
              TableColumn('Pays', (r) => cellText(r['pays'])),
              TableColumn('Coordonnées', (r) => cellText(r['latitude'] == null ? null : '${r['latitude']}, ${r['longitude']}'), flex: 3),
              TableColumn('Desservie', (r) => Switch(
                    value: r['est_couverte'] == true,
                    activeTrackColor: TC.success,
                    onChanged: (v) => _toggle(r, v),
                  ), flex: 2),
            ],
          ),
          const SizedBox(height: 24),
          TcCard(
            child: Row(children: [
              const Icon(Icons.info_outline, color: TC.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Commission plateforme : 7 % par transaction (valeur par défaut de la base). '
                  'Les grilles tarifaires se consultent dans la fiche de chaque transporteur.',
                  style: TC.body,
                ),
              ),
            ]),
          ),
        ],
      );
}

class _VilleForm extends StatefulWidget {
  const _VilleForm();

  @override
  State<_VilleForm> createState() => _VilleFormState();
}

class _VilleFormState extends State<_VilleForm> {
  final _nom = TextEditingController();
  final _pays = TextEditingController(text: 'BJ');
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String? _error;

  Future<void> _save() async {
    try {
      await context.api.post('/api/villes', {
        'nom_ville': _nom.text.trim(),
        'pays': _pays.text.trim().toUpperCase(),
        'est_couverte': true,
        if (_lat.text.isNotEmpty) 'latitude': _lat.text.trim(),
        if (_lng.text.isNotEmpty) 'longitude': _lng.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Nouvelle ville', style: TC.h3),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 12),
            TextField(controller: _pays, maxLength: 2, decoration: const InputDecoration(labelText: 'Pays (code ISO, ex. BJ)')),
            Row(children: [
              Expanded(child: TextField(controller: _lat, decoration: const InputDecoration(labelText: 'Latitude'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _lng, decoration: const InputDecoration(labelText: 'Longitude'))),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: TC.error))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: _save, child: const Text('Ajouter')),
        ],
      );
}
