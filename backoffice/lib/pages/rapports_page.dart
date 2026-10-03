import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Rapports : répartition des demandes par statut, zones actives, indicateurs de succès (KPI du cahier des charges).
class RapportsPage extends StatefulWidget {
  const RapportsPage({super.key});

  @override
  State<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends State<RapportsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = context.api.get('/api/admin/tableau-de-bord');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorBox('${snapshot.error}');
          if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(64), child: Center(child: CircularProgressIndicator()));
          final k = snapshot.data!;
          final parStatut = (k['demandes_par_statut'] as Map).cast<String, dynamic>();
          final zones = (k['zones_actives'] as List).cast<Map<String, dynamic>>();
          final statuts = [for (final s in Statuts.demande.keys) if (parStatut.containsKey(s)) s];

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader('Rapports', subtitle: 'Indicateurs de succès du projet'),
            TcCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Objectifs (cahier des charges)', style: TC.h3),
                const SizedBox(height: 16),
                _Objectif('Marchands inscrits (objectif 500 à 6 mois)', k['marchands_inscrits'] as num, 500),
                _Objectif('Transporteurs partenaires actifs (objectif 50)', k['transporteurs_actifs'] as num, 50),
                _Objectif('Taux de litige (objectif < 2 %)', (k['taux_litige_pct'] as num?) ?? 0, 2, inverse: true, suffix: ' %'),
              ]),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 24, runSpacing: 24, children: [
              SizedBox(
                width: 560,
                child: TcCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Demandes par statut', style: TC.h3),
                    const SizedBox(height: 20),
                    SimpleBarChart(
                      labels: [for (final s in statuts) _court[s] ?? s],
                      values: [for (final s in statuts) parStatut[s] as num],
                      color: TC.secondary,
                    ),
                  ]),
                ),
              ),
              SizedBox(
                width: 420,
                child: TcCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Zones les plus actives', style: TC.h3),
                    const SizedBox(height: 16),
                    RankingBars(entries: [for (final z in zones) (z['ville'] as String, z['nb_demandes'] as num)], color: TC.primary),
                    const Divider(height: 32),
                    InfoRow("Chiffre d'affaires (30 j)", fcfa(k['chiffre_affaires'])),
                    InfoRow('Commissions (30 j)', fcfa(k['commissions'])),
                    InfoRow('Taux de conversion', k['taux_conversion_pct'] == null ? null : '${k['taux_conversion_pct']} %'),
                  ]),
                ),
              ),
            ]),
          ]);
        },
      );
}

/// Libellés courts pour l'axe du graphique
const _court = {
  'EN_ATTENTE': 'Attente',
  'REPRESENTANT_ASSIGNE': 'Assigné',
  'EN_EVALUATION': 'Éval.',
  'PRIX_PROPOSE': 'Prix',
  'EN_NEGOCIATION': 'Négo.',
  'PAIEMENT_EN_ATTENTE': 'À payer',
  'PAYE': 'Payé',
  'EN_TRANSIT': 'Transit',
  'LIVRE': 'Livré',
  'ANNULE': 'Annulé',
  'LITIGE': 'Litige',
};

class _Objectif extends StatelessWidget {
  const _Objectif(this.label, this.value, this.target, {this.inverse = false, this.suffix = ''});

  final String label;
  final num value;
  final num target;
  final bool inverse;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final atteint = inverse ? value < target : value >= target;
    final progress = inverse ? (value <= target ? 1.0 : target / value) : (value / target).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TC.body)),
          Text('$value$suffix', style: TC.label.copyWith(color: atteint ? TC.success : TC.gray900)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: atteint ? TC.success : TC.primary,
            backgroundColor: TC.gray100,
          ),
        ),
      ]),
    );
  }
}
