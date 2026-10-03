import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';

/// Accès à la session depuis n'importe quel widget : `AuthScope.of(context).api`.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({super.key, required AuthController controller, required super.child})
      : super(notifier: controller);

  static AuthController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}

extension ApiContext on BuildContext {
  ApiClient get api => AuthScope.of(this).api;
}

/// Badge de statut (pill, couleur selon le statut).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.value, this.palette, {super.key});

  final String? value;
  final Map<String, (String, Color)> palette;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text('—', style: TC.caption);
    }
    final (label, color) = palette[value] ?? (value!, TC.gray600);
    // Maquette : fond teinté, pastille et texte de la couleur du statut
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), TC.white),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

/// Carte blanche à coins arrondis et ombre douce.
class TcCard extends StatelessWidget {
  const TcCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: TC.white,
          borderRadius: BorderRadius.circular(TC.radiusLg),
          boxShadow: TC.shadowSm,
        ),
        child: child,
      );
}

/// Indicateur du tableau de bord (maquette A01) : libellé, valeur, évolution.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, this.trend, this.trendColor});

  final String label;
  final String value;
  final String? trend;
  final Color? trendColor;

  @override
  Widget build(BuildContext context) => TcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TC.muted.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: TC.kpi, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            // Ligne toujours réservée : toutes les cartes ont la même hauteur
            Text(
              trend ?? '',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: trendColor ?? TC.positive),
            ),
          ],
        ),
      );
}

/// En-tête de page : titre, sous-titre, actions.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TC.h1),
                if (subtitle != null) Text(subtitle!, style: TC.muted),
              ],
            ),
            Wrap(spacing: 12, runSpacing: 8, children: actions),
          ],
        ),
      );
}

/// Ligne « libellé : valeur » des fiches de détail.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 170, child: Text(label, style: TC.label)),
            Expanded(
              child: value is Widget ? value as Widget : SelectableText('${value ?? '—'}', style: TC.body),
            ),
          ],
        ),
      );
}

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? TC.error : TC.success,
    duration: const Duration(seconds: 3),
  ));
}

/// Exécute une action API et affiche le résultat (toast vert / rouge).
Future<bool> runAction(BuildContext context, Future<void> Function() action, {required String success}) async {
  try {
    await action();
    if (context.mounted) toast(context, success);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
    return false;
  }
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String confirmLabel = 'Confirmer', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: TC.h3),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: TC.error) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Liste déroulante de filtre (valeur vide = tous).
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        child: DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous')),
            for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: onChanged,
        ),
      );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onSubmitted});

  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        child: TextField(
          decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search), isDense: true),
          onSubmitted: onSubmitted,
        ),
      );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: TC.error, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
              ],
            ],
          ),
        ),
      );
}
