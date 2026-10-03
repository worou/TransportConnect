import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// M13 — Profil (marchand ou représentant).
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key, this.onDemandes});

  /// Ouvre l'onglet des demandes / missions.
  final VoidCallback? onDemandes;

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Future<List<int>>? _stats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stats ??= _load();
  }

  /// Marchand : envois, en cours, litiges. Représentant : évaluations, devis, devis acceptés.
  Future<List<int>> _load() async {
    final s = context.session;
    if (s.role == 'marchand') {
      final d = await s.api.list('/api/demandes');
      return [d.length, d.where((x) => Statuts.enCours.contains(x['statut'])).length, d.where((x) => x['statut'] == 'LITIGE').length];
    }
    final e = await s.api.list('/api/evaluations', query: {'representant': s.meIri});
    final soumises = e.where((x) => x['date_soumission'] != null).length;
    return [e.length, soumises, e.length - soumises];
  }

  Future<void> _modifierNom() async {
    final c = TextEditingController(text: context.session.me?['nom_complet'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Votre nom', style: TC.h3),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || !mounted || c.text.trim().isEmpty) return;
    final s = context.session;
    if (await act(context, () => s.api.patch(s.meIri, {'nom_complet': c.text.trim()}), success: 'Nom enregistré.')) {
      await s.reloadMe();
    }
  }

  void _aide() => showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aide et support', style: TC.h3),
              const SizedBox(height: 10),
              Text(
                'Une question sur une demande, un paiement ou une livraison ? Contactez le support TransportConnect '
                'en indiquant le numéro de votre demande (TC-…).',
                style: TC.body,
              ),
              const SizedBox(height: 12),
              Text('En cas de problème à la livraison, ne donnez pas votre code de réception et signalez-le au support.', style: TC.small),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    final me = s.me!;
    final marchand = s.role == 'marchand';
    final ville = s.ville(me['ville_residence'] as String?);
    final roleTxt = switch (s.role) {
      'marchand' => 'Marchand',
      'representant' => 'Représentant',
      'chauffeur' => 'Chauffeur',
      _ => s.role,
    };
    final labels = marchand ? ['Envois', 'En cours', 'Litiges'] : ['Missions', 'Évaluées', 'En cours'];

    Widget item(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? TC.primary),
          title: Text(label, style: TC.strong.copyWith(color: color)),
          trailing: color == null ? const Icon(Icons.chevron_right, color: TC.muted) : null,
          onTap: onTap,
        );

    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Text('Mon profil', style: TC.h2),
      const SizedBox(height: 16),
      Panel(
        child: Column(children: [
          Initials(me['nom_complet'] as String?, size: 72),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(me['nom_complet'] as String? ?? 'Nom à compléter', style: TC.h2, textAlign: TextAlign.center)),
            IconButton(tooltip: 'Modifier le nom', onPressed: _modifierNom, icon: const Icon(Icons.edit_outlined, size: 18, color: TC.primary)),
          ]),
          Text([roleTxt, if (ville != null) ville['nom_ville'], if (me['nom_transporteur'] != null) me['nom_transporteur']].join(' · '), style: TC.small),
          Text('${me['telephone']}', style: TC.small),
          if (me['note_moyenne'] != null) ...[
            const SizedBox(height: 6),
            Text('★ ${'${me['note_moyenne']}'.replaceAll('.', ',')} · ${me['nb_avis']} avis', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: TC.ink)),
          ],
          const SizedBox(height: 14),
          FutureBuilder<List<int>>(
            future: _stats,
            builder: (c, snap) => Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Column(children: [
                    Text(snap.hasData ? nombre(snap.data![i]) : '–', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: TC.ink)),
                    Text(labels[i], style: TC.small),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          if (widget.onDemandes != null) item(Icons.inventory_2_outlined, marchand ? 'Mes demandes' : 'Mes missions', widget.onDemandes!),
          item(Icons.help_outline, 'Aide et support', _aide),
          item(Icons.logout, 'Déconnexion', () async {
            if (await confirm(context, 'Déconnexion', 'Vous devrez saisir un nouveau code pour vous reconnecter.', ok: 'Se déconnecter')) {
              s.logout();
            }
          }, color: TC.error),
        ]),
      ),
      const SizedBox(height: 16),
      Center(child: Text('TransportConnect · version 1.0.0', style: TC.caption)),
    ]);
  }
}
