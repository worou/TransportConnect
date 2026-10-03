import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'theme.dart';

/// Logo « Maillons » : symbole + transport/connect.
class TcLogo extends StatelessWidget {
  const TcLogo({super.key, this.dark = false, this.height = 22, this.fontSize = 20});

  final bool dark;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset(dark ? 'assets/logo/mark-dark.svg' : 'assets/logo/mark.svg',
            height: height, width: height * 63 / 26, semanticsLabel: 'TransportConnect'),
        SizedBox(width: height * 0.35),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'transport', style: GoogleFonts.poppins(fontWeight: FontWeight.w400)),
            TextSpan(text: 'connect', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ]),
          style: GoogleFonts.poppins(fontSize: fontSize, color: dark ? TC.white : TC.navy, height: 1),
        ),
      ]);
}

/// Bouton carré 44 px bordé (retour, notifications…).
class SquareButton extends StatelessWidget {
  const SquareButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.dot = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool dot;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: TC.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TC.radius), side: const BorderSide(color: TC.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(TC.radius),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(alignment: Alignment.center, children: [
                Icon(icon, size: 20, color: TC.ink),
                if (dot)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: TC.secondary, shape: BoxShape.circle, border: Border.all(color: TC.white, width: 2)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}

/// En-tête des écrans secondaires : retour + titre (+ sous-titre).
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(children: [
          SquareButton(icon: Icons.arrow_back, tooltip: 'Retour', onPressed: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TC.title, overflow: TextOverflow.ellipsis),
              if (subtitle != null) Text(subtitle!, style: TC.small, overflow: TextOverflow.ellipsis),
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// Carte blanche arrondie à ombre douce.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = TC.white});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: TC.cardShadow),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// Badge de statut : fond teinté, pastille et texte de la couleur du statut.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.statut, {super.key});

  final String? statut;

  @override
  Widget build(BuildContext context) {
    final (label, color, _) = Statuts.demande[statut] ?? (statut ?? '—', TC.muted, 0.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Color.alphaBlend(color.withValues(alpha: 0.10), TC.white), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

/// Barre d'étapes d'un parcours (n/total).
class StepsBar extends StatelessWidget {
  const StepsBar({super.key, required this.step, required this.total, required this.label});

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(children: [
          Row(children: [
            for (var i = 1; i <= total; i++) ...[
              Expanded(
                child: Container(height: 4, decoration: BoxDecoration(color: i <= step ? TC.primary : TC.border, borderRadius: BorderRadius.circular(2))),
              ),
              if (i < total) const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: TC.primary)),
            const Spacer(),
            Text('Étape $step/$total', style: TC.small),
          ]),
        ]),
      );
}

/// Zone d'actions fixe en bas d'écran.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: TC.white, border: Border(top: BorderSide(color: TC.border))),
        child: Row(children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(flex: i == children.length - 1 && children.length > 1 ? 2 : 1, child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 10),
          ],
        ]),
      );
}

/// Libellé + champ.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.help});

  final String label;
  final Widget child;
  final String? help;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: TC.label),
        const SizedBox(height: 6),
        child,
        if (help != null) ...[const SizedBox(height: 4), Text(help!, style: TC.caption)],
      ]);
}

/// Choix exclusif en pastilles (type de marchandise, opérateur…).
class ChoiceGrid extends StatelessWidget {
  const ChoiceGrid({super.key, required this.options, required this.value, required this.onChanged, this.columns = 3});

  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in options.entries)
            SizedBox(
              width: w,
              height: 44,
              child: e.key == value
                  ? FilledButton(
                      onPressed: () => onChanged(e.key),
                      style: FilledButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    )
                  : OutlinedButton(
                      onPressed: () => onChanged(e.key),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        foregroundColor: TC.ink,
                        backgroundColor: TC.white,
                        side: const BorderSide(color: TC.border, width: 1.5),
                        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
            ),
        ]);
      });
}

/// Sélecteur segmenté (Normale / Express…).
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: TC.segment, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (final e in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e.key == value ? TC.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: e.key == value ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(e.value,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: e.key == value ? TC.primary : TC.muted)),
                ),
              ),
            ),
        ]),
      );
}

/// Pastille d'initiales.
class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = 44});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    final txt = parts.isEmpty ? '?' : parts.map((p) => p[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: TC.primary100, shape: BoxShape.circle),
      child: Text(txt, style: GoogleFonts.poppins(color: TC.primary, fontWeight: FontWeight.w600, fontSize: size * 0.34)),
    );
  }
}

/// Encadré d'information bleu clair.
class InfoBox extends StatelessWidget {
  const InfoBox(this.text, {super.key, this.icon = Icons.verified_user_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: TC.primary100, borderRadius: BorderRadius.circular(TC.radius)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: TC.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, height: 19 / 13, color: TC.ink))),
        ]),
      );
}

/// Chargement d'un écran : indicateur, erreur avec « Réessayer », puis contenu.
class Loader<T> extends StatelessWidget {
  const Loader({super.key, required this.future, required this.builder, required this.onRetry});

  final Future<T>? future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (context, s) {
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 40, color: TC.muted),
                  const SizedBox(height: 12),
                  Text('${s.error}', textAlign: TextAlign.center, style: TC.bodyMuted),
                  const SizedBox(height: 12),
                  TextButton(onPressed: onRetry, child: const Text('Réessayer')),
                ]),
              ),
            );
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          return builder(s.data as T);
        },
      );
}

void toast(BuildContext context, String message, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? TC.error : TC.success),
    );

/// Exécute une action API ; affiche l'erreur éventuelle. Renvoie true si elle a réussi.
Future<bool> act(BuildContext context, Future<void> Function() f, {String? success}) async {
  try {
    await f();
    if (success != null && context.mounted) toast(context, success);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
    return false;
  }
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'Confirmer', bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: TC.h3),
        content: Text(message, style: TC.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: danger ? TC.error : TC.primary),
            child: Text(ok),
          ),
        ],
      ),
    ) ??
    false;

Future<void> appeler(String telephone) => launchUrl(Uri(scheme: 'tel', path: telephone));

Future<void> openMaps(String query) =>
    launchUrl(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}), mode: LaunchMode.externalApplication);

/// Distance à vol d'oiseau en mètres (formule de haversine).
double distanceMetres(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
