import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/resource_table.dart';

/// Comptes utilisateurs (validation, suspension, création) et vérification des documents KYC.
class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({super.key, this.ongletKyc = false, this.nom});

  final bool ongletKyc;

  /// Recherche initiale (barre de recherche du haut)
  final String? nom;

  @override
  State<UtilisateursPage> createState() => _UtilisateursPageState();
}

class _UtilisateursPageState extends State<UtilisateursPage> {
  final _comptes = GlobalKey<ResourceTableState>();
  final _kyc = GlobalKey<ResourceTableState>();
  String? _role;
  String? _statut;
  late String _nom = widget.nom ?? '';
  String? _statutKyc = 'en_attente';
  late int _onglet = widget.ongletKyc ? 1 : 0;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        initialIndex: widget.ongletKyc ? 1 : 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader('Utilisateurs', subtitle: 'Marchands, représentants, chauffeurs et administrateurs', actions: [
              FilledButton.icon(
                onPressed: () async {
                  if (await showUtilisateurForm(context)) _comptes.currentState?.reload();
                },
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Nouveau compte'),
              ),
            ]),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (i) => setState(() => _onglet = i),
              tabs: const [Tab(text: 'Comptes'), Tab(text: 'Documents KYC')],
            ),
            const SizedBox(height: 16),
            if (_onglet == 0)
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    FilterDropdown(label: 'Rôle', value: _role, options: Statuts.roles, onChanged: (v) => setState(() => _role = v)),
                    FilterDropdown(
                      label: 'Statut',
                      value: _statut,
                      options: {for (final e in Statuts.compte.entries) e.key: e.value.$1},
                      onChanged: (v) => setState(() => _statut = v),
                    ),
                    SearchField(hint: _nom.isEmpty ? 'Nom' : _nom, onSubmitted: (v) => setState(() => _nom = v.trim())),
                  ]),
                  const SizedBox(height: 16),
                  ResourceTable(
                    key: _comptes,
                    path: '/api/utilisateurs',
                    query: {'role': _role ?? '', 'statut_compte': _statut ?? '', 'nom_complet': _nom},
                    columns: [
                      TableColumn('Nom', (r) => cellText(r['nom_complet'], bold: true), flex: 3),
                      TableColumn('Téléphone', (r) => cellText(r['telephone']), flex: 2),
                      TableColumn('Rôle', (r) => cellText(Statuts.roles[r['role']]), flex: 2),
                      TableColumn('Transporteur', (r) => cellText(r['nom_transporteur']), flex: 2),
                      TableColumn('Note', (r) => cellText(r['note_moyenne'] == null ? null : '★ ${r['note_moyenne']} (${r['nb_avis']})')),
                      TableColumn('Statut', (r) => StatusBadge(r['statut_compte'] as String?, Statuts.compte), flex: 2),
                      TableColumn('Inscription', (r) => cellText(date(r['date_inscription'])), flex: 2),
                    ],
                    onTap: (row) async {
                      await showDialog(context: context, builder: (_) => _UtilisateurDetail(row));
                      _comptes.currentState?.reload();
                    },
                  ),
                ])
            else
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(children: [
                    FilterDropdown(
                      label: 'Vérification',
                      value: _statutKyc,
                      options: {for (final e in Statuts.kyc.entries) e.key: e.value.$1},
                      onChanged: (v) => setState(() => _statutKyc = v),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  ResourceTable(
                    key: _kyc,
                    path: '/api/document_kycs',
                    query: {'statut_verification': _statutKyc ?? ''},
                    emptyMessage: 'Aucun document à afficher.',
                    columns: [
                      TableColumn('Utilisateur', (r) => cellText(r['nom_utilisateur'], bold: true), flex: 3),
                      TableColumn('Téléphone', (r) => cellText(r['telephone_utilisateur']), flex: 2),
                      TableColumn('Document', (r) => cellText(_typeDoc[r['type_document']] ?? r['type_document']), flex: 2),
                      TableColumn('Déposé le', (r) => cellText(date(r['date_depot'])), flex: 2),
                      TableColumn('Statut', (r) => StatusBadge(r['statut_verification'] as String?, Statuts.kyc), flex: 2),
                      TableColumn('', (r) => KycActions(r, onDone: () => _kyc.currentState?.reload()), flex: 3),
                    ],
                  ),
                ]),
          ],
        ),
      );
}

const _typeDoc = {
  'cni_recto': 'CNI (recto)',
  'cni_verso': 'CNI (verso)',
  'selfie': 'Selfie',
  'registre_commerce': 'Registre de commerce',
  'badge': 'Badge',
  'contrat': 'Contrat',
};

/// Boutons Valider / Rejeter d'un document KYC.
class KycActions extends StatelessWidget {
  const KycActions(this.doc, {super.key, required this.onDone});

  final Map<String, dynamic> doc;
  final VoidCallback onDone;

  Future<void> _decide(BuildContext context, bool valide) async {
    String? motif;
    if (!valide) {
      motif = await _prompt(context, 'Motif du rejet', 'Ex. : photo illisible, document expiré…');
      if (motif == null) return;
    }
    if (!context.mounted) return;
    final ok = await runAction(
      context,
      () => context.api.patch(doc['@id'] as String, {
        'statut_verification': valide ? 'valide' : 'rejete',
        'motif_rejet': motif,
        'verifie_par': AuthScope.of(context).userIri,
        'verifie_le': DateTime.now().toUtc().toIso8601String(),
      }),
      success: valide ? 'Document validé.' : 'Document rejeté.',
    );
    if (ok) onDone();
  }

  @override
  Widget build(BuildContext context) => Wrap(spacing: 4, children: [
        IconButton(
          tooltip: 'Ouvrir le fichier',
          icon: const Icon(Icons.open_in_new, size: 20),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Fichier'),
              content: SelectableText('${doc['url_fichier']}'),
            ),
          ),
        ),
        if (doc['statut_verification'] != 'valide')
          TextButton(onPressed: () => _decide(context, true), child: const Text('Valider')),
        if (doc['statut_verification'] != 'rejete')
          TextButton(
            style: TextButton.styleFrom(foregroundColor: TC.error),
            onPressed: () => _decide(context, false),
            child: const Text('Rejeter'),
          ),
      ]);
}

Future<String?> _prompt(BuildContext context, String title, String hint) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: TC.h3),
      content: SizedBox(width: 340, child: TextField(controller: c, autofocus: true, maxLines: 3, decoration: InputDecoration(hintText: hint))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim().isEmpty ? null : c.text.trim()), child: const Text('Valider')),
      ],
    ),
  );
}

class _UtilisateurDetail extends StatefulWidget {
  const _UtilisateurDetail(this.user);

  final Map<String, dynamic> user;

  @override
  State<_UtilisateurDetail> createState() => _UtilisateurDetailState();
}

class _UtilisateurDetailState extends State<_UtilisateurDetail> {
  late Map<String, dynamic> u = widget.user;
  late Future<ApiPage> _docs = _loadDocs();

  Future<ApiPage> _loadDocs() => context.api.list('/api/document_kycs', query: {'utilisateur': u['@id'] as String});

  Future<void> _setStatut(String statut) async {
    final suspendre = statut == 'suspendu';
    if (suspendre &&
        !await confirm(context, 'Suspendre le compte', '${u['nom_complet']} ne pourra plus se connecter.',
            confirmLabel: 'Suspendre', danger: true)) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () async {
      final r = await context.api.patch(u['@id'] as String, {'statut_compte': statut});
      setState(() => u = r);
    }, success: suspendre ? 'Compte suspendu.' : 'Compte activé.');
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: TC.primary100,
                    child: Text('${u['nom_complet'] ?? '?'}'[0], style: TC.h3.copyWith(color: TC.primary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${u['nom_complet'] ?? 'Sans nom'}', style: TC.h2),
                      Text('${Statuts.roles[u['role']]} · ${u['telephone']}', style: TC.caption),
                    ]),
                  ),
                  StatusBadge(u['statut_compte'] as String?, Statuts.compte),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                const Divider(height: 32),
                InfoRow('Transporteur', u['nom_transporteur']),
                InfoRow('Activité', u['type_activite']),
                InfoRow('Disponibilité', u['disponibilite']),
                InfoRow('Note', u['note_moyenne'] == null ? null : '★ ${u['note_moyenne']} (${u['nb_avis']} avis)'),
                InfoRow('Zones', (u['zones_intervention'] as List?)?.isEmpty ?? true ? null : '${(u['zones_intervention'] as List).length} ville(s)'),
                InfoRow('Inscription', dateHeure(u['date_inscription'])),
                const SizedBox(height: 16),
                Text('Documents KYC', style: TC.h3),
                FutureBuilder<ApiPage>(
                  future: _docs,
                  builder: (context, s) {
                    if (!s.hasData) return const LinearProgressIndicator();
                    if (s.data!.items.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text('Aucun document déposé.', style: TC.caption));
                    return Column(children: [
                      for (final doc in s.data!.items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_typeDoc[doc['type_document']] ?? '${doc['type_document']}'),
                          subtitle: Text('Déposé le ${date(doc['date_depot'])}'
                              '${doc['motif_rejet'] != null ? ' — ${doc['motif_rejet']}' : ''}'),
                          trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                            StatusBadge(doc['statut_verification'] as String?, Statuts.kyc),
                            KycActions(doc, onDone: () => setState(() => _docs = _loadDocs())),
                          ]),
                        ),
                    ]);
                  },
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (u['statut_compte'] != 'actif')
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: TC.success),
                      onPressed: () => _setStatut('actif'),
                      icon: const Icon(Icons.check),
                      label: Text(u['statut_compte'] == 'suspendu' ? 'Réactiver' : 'Valider le compte'),
                    ),
                  if (u['statut_compte'] != 'suspendu' && u['role'] != 'admin') ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: TC.error, side: const BorderSide(color: TC.error, width: 2)),
                      onPressed: () => _setStatut('suspendu'),
                      icon: const Icon(Icons.block),
                      label: const Text('Suspendre'),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ),
      );
}

/// Création d'un compte représentant / chauffeur / admin (les marchands s'inscrivent seuls).
Future<bool> showUtilisateurForm(BuildContext context) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => const _UtilisateurForm());
  return ok ?? false;
}

class _UtilisateurForm extends StatefulWidget {
  const _UtilisateurForm();

  @override
  State<_UtilisateurForm> createState() => _UtilisateurFormState();
}

class _UtilisateurFormState extends State<_UtilisateurForm> {
  final _tel = TextEditingController(text: '+229');
  final _nom = TextEditingController();
  String _role = 'representant';
  String? _transporteur;
  final Set<String> _zones = {};
  late final Future<List<ApiPage>> _refs = Future.wait([
    context.api.list('/api/transporteurs', query: {'statut': 'actif'}),
    context.api.list('/api/villes', query: {'est_couverte': 'true'}),
  ]);
  String? _error;

  bool get _rattache => _role == 'representant' || _role == 'chauffeur';

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      await context.api.post('/api/utilisateurs', {
        'telephone': _tel.text.replaceAll(' ', ''),
        'nom_complet': _nom.text.trim(),
        'role': _role,
        'statut_compte': 'actif',
        'transporteur': _rattache ? _transporteur : null,
        if (_role == 'representant') 'zones_intervention': _zones.toList(),
        if (_rattache) 'disponibilite': 'hors_ligne',
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Nouveau compte', style: TC.h3),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<List<ApiPage>>(
            future: _refs,
            builder: (context, s) {
              if (!s.hasData) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
              final transporteurs = s.data![0].items;
              final villes = s.data![1].items;
              return SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom complet')),
                  const SizedBox(height: 12),
                  TextField(controller: _tel, decoration: const InputDecoration(labelText: 'Téléphone')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Rôle'),
                    items: const [
                      DropdownMenuItem(value: 'representant', child: Text('Représentant')),
                      DropdownMenuItem(value: 'chauffeur', child: Text('Chauffeur')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                  if (_rattache) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _transporteur,
                      decoration: const InputDecoration(labelText: 'Transporteur'),
                      items: [
                        for (final t in transporteurs)
                          DropdownMenuItem(value: t['@id'] as String, child: Text('${t['raison_sociale']}')),
                      ],
                      onChanged: (v) => setState(() => _transporteur = v),
                    ),
                  ],
                  if (_role == 'representant') ...[
                    const SizedBox(height: 16),
                    Text("Zones d'intervention", style: TC.label),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final v in villes)
                        FilterChip(
                          label: Text('${v['nom_ville']}'),
                          selected: _zones.contains(v['@id']),
                          onSelected: (on) => setState(() => on ? _zones.add(v['@id'] as String) : _zones.remove(v['@id'])),
                        ),
                    ]),
                  ],
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: TC.error))),
                ]),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: _rattache && _transporteur == null ? null : _save, child: const Text('Créer')),
        ],
      );
}
