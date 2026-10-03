import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../export_csv.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/resource_table.dart';
import 'demandes_page.dart';

const _periodes = {7: '7 j', 30: '30 j', 365: '12 mois'};
const _libellesPeriode = {7: '7 derniers jours', 30: '30 derniers jours', 365: '12 derniers mois'};
const _comparaison = {7: 'vs semaine précédente', 30: 'vs mois précédent', 365: 'vs année précédente'};

/// Tableau de bord (maquette A01) : 4 indicateurs, demandes par jour, zones actives, demandes récentes.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _periode = 30;
  Future<Map<String, dynamic>>? _future;
  bool _export = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() => context.api.get('/api/admin/tableau-de-bord', query: {'periode': '$_periode'});

  void _setPeriode(int p) => setState(() {
        _periode = p;
        _future = _load();
      });

  Future<void> _exporter() async {
    setState(() => _export = true);
    try {
      final n = await exporterCsv(
        context.api,
        path: '/api/suivi_demandes',
        fichier: 'demandes-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        colonnes: {
          'Numéro': (r) => '${r['numero']}',
          'Départ': (r) => '${r['ville_depart']}',
          'Arrivée': (r) => '${r['ville_arrivee']}',
          'Marchand': (r) => '${r['marchand'] ?? ''}',
          'Transporteur': (r) => '${r['transporteur'] ?? ''}',
          'Statut': (r) => Statuts.demande[r['statut']]?.$1 ?? '${r['statut']}',
          'Montant (FCFA)': (r) => '${r['prix_propose'] ?? ''}',
          'Créée le': (r) => date(r['created_at']),
        },
      );
      if (mounted) toast(context, '$n demande(s) exportée(s).');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  /// « +12 % vs mois précédent » (vert), « −8 % … » (rouge), rien sans période de référence.
  (String?, Color?) _evolution(Object? pct) {
    if (pct == null) return (null, null);
    final v = (pct as num).toDouble();
    final signe = v > 0 ? '+' : (v < 0 ? '−' : '');
    final texte = '$signe${v.abs().toStringAsFixed(v.abs() < 10 && v != v.roundToDouble() ? 1 : 0)} % ${_comparaison[_periode]}';
    return (texte, v < 0 ? TC.error : TC.positive);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            'Tableau de bord',
            subtitle: "Vue d'ensemble · ${_libellesPeriode[_periode]}",
            actions: [
              for (final e in _periodes.entries)
                _PeriodButton(label: e.value, selected: _periode == e.key, onPressed: () => _setPeriode(e.key)),
              FilledButton.icon(
                onPressed: _export ? null : _exporter,
                icon: _export
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TC.white))
                    : const Icon(Icons.download_outlined, size: 18),
                label: const Text('Exporter'),
              ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorBox('${snapshot.error}', onRetry: () => setState(() => _future = _load()));
              }
              if (!snapshot.hasData) {
                return const Padding(padding: EdgeInsets.all(64), child: Center(child: CircularProgressIndicator()));
              }
              final k = snapshot.data!;
              final jours = (k['demandes_par_jour'] as List).cast<Map<String, dynamic>>();
              final zones = (k['zones_actives'] as List).cast<Map<String, dynamic>>();
              final (evoDemandes, couleurDemandes) = _evolution(k['demandes_evolution_pct']);
              final (evoCa, couleurCa) = _evolution(k['chiffre_affaires_evolution_pct']);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Grid(minWidth: 220, gap: 20, children: [
                    KpiCard(label: 'Demandes', value: nombre(k['demandes'] as num), trend: evoDemandes, trendColor: couleurDemandes),
                    KpiCard(
                      label: 'Transporteurs actifs',
                      value: nombre(k['transporteurs_actifs'] as num),
                      trend: _nouveaux(k['transporteurs_nouveaux'] as int, 'nouveau', 'nouveaux'),
                    ),
                    KpiCard(
                      label: 'Marchands inscrits',
                      value: nombre(k['marchands_inscrits'] as num),
                      trend: _nouveaux(k['marchands_nouveaux'] as int, 'sur la période', 'sur la période'),
                    ),
                    KpiCard(
                      label: "Chiffre d'affaires",
                      value: fcfaCompact(k['chiffre_affaires'] as num),
                      trend: evoCa ?? 'Commissions : ${fcfa(k['commissions'])}',
                      trendColor: couleurCa ?? TC.gray600,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  LayoutBuilder(builder: (context, c) {
                    final graphique = TcCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text('Demandes par jour', style: TC.h3)),
                            Text('14 derniers jours', style: TC.muted.copyWith(fontSize: 13)),
                          ]),
                          const SizedBox(height: 16),
                          SimpleBarChart(
                            height: 200,
                            labels: [for (final j in jours) (j['jour'] as String).substring(8)],
                            values: [for (final j in jours) j['nb_demandes'] as num],
                            highlightLast: true,
                          ),
                          const SizedBox(height: 14),
                          Wrap(spacing: 24, runSpacing: 6, children: [
                            _Indicateur('Taux de conversion devis → paiement',
                                k['taux_conversion_pct'] == null ? '—' : '${_virgule(k['taux_conversion_pct'])} %'),
                            _Indicateur("Délai moyen d'évaluation", _duree(k['delai_moyen_evaluation_minutes'] as int?)),
                          ]),
                        ],
                      ),
                    );
                    final zonesCard = TcCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Zones les plus actives', style: TC.h3),
                          const SizedBox(height: 14),
                          if (zones.isEmpty) Text('Aucune demande sur la période.', style: TC.muted),
                          for (final z in zones)
                            _ZoneBar(
                              ville: z['ville'] as String,
                              valeur: z['nb_demandes'] as int,
                              max: zones.first['nb_demandes'] as int,
                            ),
                        ],
                      ),
                    );
                    if (c.maxWidth < 900) {
                      return Column(children: [graphique, const SizedBox(height: 20), zonesCard]);
                    }
                    return IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(flex: 2, child: graphique),
                        const SizedBox(width: 20),
                        Expanded(child: zonesCard),
                      ]),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          TcCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                  child: Row(children: [
                    Expanded(child: Text('Demandes récentes', style: TC.h3)),
                    TextButton(onPressed: () => context.go('/demandes'), child: const Text('Voir toutes')),
                  ]),
                ),
                ResourceTable(
                  path: '/api/suivi_demandes',
                  columns: demandeColumns(compact: true),
                  onTap: (row) => showDemandeDetail(context, row),
                  bare: true,
                ),
              ],
            ),
          ),
        ],
      );

  static String? _nouveaux(int n, String singulier, String pluriel) => n == 0 ? null : '+$n ${n > 1 ? pluriel : singulier}';

  static String _virgule(Object? v) => '$v'.replaceAll('.0', '').replaceAll('.', ',');

  /// 460 → « 7 h 40 »
  static String _duree(int? minutes) {
    if (minutes == null) return '—';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)), child: Text(label))
      : OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: TC.gray900,
            backgroundColor: TC.white,
            side: const BorderSide(color: TC.gray200, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Text(label),
        );
}

class _Indicateur extends StatelessWidget {
  const _Indicateur(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(
        style: TC.muted.copyWith(fontSize: 13),
        children: [
          TextSpan(text: '$label : '),
          TextSpan(text: valeur, style: const TextStyle(color: TC.gray900, fontWeight: FontWeight.w700)),
        ],
      ));
}

class _ZoneBar extends StatelessWidget {
  const _ZoneBar({required this.ville, required this.valeur, required this.max});

  final String ville;
  final int valeur;
  final int max;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(ville, style: TC.body.copyWith(fontWeight: FontWeight.w500))),
            Text('$valeur', style: TC.muted),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : valeur / max,
              minHeight: 6,
              color: TC.primary,
              backgroundColor: TC.gray200,
            ),
          ),
        ]),
      );
}

/// Grille responsive : autant de colonnes que la largeur le permet.
class _Grid extends StatelessWidget {
  const _Grid({required this.children, required this.minWidth, this.gap = 16});

  final List<Widget> children;
  final double minWidth;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = ((c.maxWidth + gap) / (minWidth + gap)).floor().clamp(1, children.length);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      });
}
