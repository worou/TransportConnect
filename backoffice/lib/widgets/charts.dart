import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Histogramme simple (une série), libellés en abscisse.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.color = TC.primary,
    this.height = 220,
    this.highlightLast = false,
  });

  final List<String> labels;
  final List<num> values;
  final Color color;
  final double height;

  /// Dernière barre (aujourd'hui) en orange, comme sur la maquette.
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<num>(0, (m, v) => v > m ? v : m);
    // Axe en multiples de 4 pour des graduations entières
    final top = ((max * 1.2) / 4).ceil().clamp(1, 1 << 30) * 4.0;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) => const FlLine(color: TC.gray200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => TC.gray900,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${labels[group.x]}\n${rod.toY.toInt()}',
                const TextStyle(color: TC.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: top / 4,
                getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: TC.caption),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[v.toInt()], style: TC.caption),
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  color: highlightLast && i == values.length - 1 ? TC.secondary : color,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Barres horizontales (classement), ex. zones les plus actives.
class RankingBars extends StatelessWidget {
  const RankingBars({super.key, required this.entries, this.color = TC.secondary});

  final List<(String, num)> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('Aucune donnée.', style: TC.caption);
    }
    final max = entries.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final (label, value) in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 130, child: Text(label, style: TC.body, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : value / max,
                      minHeight: 10,
                      color: color,
                      backgroundColor: TC.gray100,
                    ),
                  ),
                ),
                SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.right, style: TC.label)),
              ],
            ),
          ),
      ],
    );
  }
}
