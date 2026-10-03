import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import 'common.dart';
import 'logo.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon, {this.badge});

  final String path;
  final String label;
  final IconData icon;

  /// Compteur affiché à droite, lu dans les statistiques admin.
  final int Function(Map<String, dynamic> stats)? badge;
}

final navItems = [
  const NavItem('/', 'Tableau de bord', Icons.grid_view_outlined),
  NavItem('/utilisateurs', 'Utilisateurs', Icons.people_outline,
      badge: (s) => (s['kyc_en_attente'] as int? ?? 0) + (s['comptes_en_attente'] as int? ?? 0)),
  const NavItem('/transporteurs', 'Transporteurs', Icons.local_shipping_outlined),
  const NavItem('/demandes', 'Demandes', Icons.inventory_2_outlined),
  const NavItem('/paiements', 'Paiements', Icons.credit_card_outlined),
  NavItem('/litiges', 'Litiges', Icons.warning_amber_outlined, badge: (s) => s['litiges_ouverts'] as int? ?? 0),
  const NavItem('/rapports', 'Rapports', Icons.bar_chart_outlined),
  const NavItem('/config', 'Configuration', Icons.settings_outlined),
];

/// Mise en page du back-office (maquette A01) : barre latérale bleue + en-tête blanc.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AuthScope.of(context).stats == null) AuthScope.of(context).refreshStats();
  }

  @override
  void didUpdateWidget(AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compteurs à jour à chaque changement d'écran
    if (oldWidget.location != widget.location) AuthScope.of(context).refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final sidebar = _Sidebar(location: widget.location);

    return Scaffold(
      drawer: wide ? null : Drawer(width: 248, child: sidebar),
      body: Row(
        children: [
          if (wide) SizedBox(width: 248, child: sidebar),
          Expanded(
            child: Column(
              children: [
                _TopBar(showMenu: !wide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: wide ? const EdgeInsets.fromLTRB(32, 28, 32, 32) : const EdgeInsets.all(16),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location});

  final String location;

  bool _active(String path) => path == '/' ? location == '/' : location.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final stats = AuthScope.of(context).stats ?? const {};
    final infoStyle = GoogleFonts.inter(color: TC.sidebarText, fontSize: 12, height: 1.5);
    final infoBold = GoogleFonts.inter(color: TC.white, fontSize: 12, fontWeight: FontWeight.w700);

    return Container(
      color: TC.sidebar,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: TcLogo(dark: true, markSize: 18, fontSize: 17),
            ),
          ),
          for (final item in navItems)
            _NavTile(item: item, active: _active(item.path), count: item.badge?.call(stats) ?? 0),
          const Spacer(),
          if (stats.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TC.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(TC.radiusMd),
              ),
              child: Text.rich(TextSpan(style: infoStyle, children: [
                const TextSpan(text: 'Commission actuelle : '),
                TextSpan(text: '${_pct(stats['taux_commission_pct'])} %', style: infoBold),
                const TextSpan(text: '\nVilles couvertes : '),
                TextSpan(text: '${stats['villes_couvertes']}', style: infoBold),
              ])),
            ),
        ],
      ),
    );
  }

  static String _pct(Object? v) {
    final n = (v as num?) ?? 0;
    return n == n.roundToDouble() ? '${n.toInt()}' : '$n'.replaceAll('.', ',');
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active, required this.count});

  final NavItem item;
  final bool active;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = active ? TC.white : TC.sidebarText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? TC.white.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: TC.white.withValues(alpha: 0.06),
          onTap: () {
            Scaffold.maybeOf(context)?.closeDrawer();
            context.go(item.path);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      )),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: TC.secondary, borderRadius: BorderRadius.circular(10)),
                    child: Text('$count',
                        style: GoogleFonts.inter(color: TC.gray900, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showMenu});

  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final nom = (auth.user?['nom_complet'] as String?)?.trim();
    final initiales = (nom == null || nom.isEmpty)
        ? 'AD'
        : nom.split(RegExp(r'\s+')).take(2).map((m) => m[0].toUpperCase()).join();
    final stats = auth.stats ?? const {};
    final alertes = (stats['litiges_ouverts'] as int? ?? 0) + (stats['kyc_en_attente'] as int? ?? 0);

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: showMenu ? 12 : 32),
      decoration: const BoxDecoration(color: TC.white, border: Border(bottom: BorderSide(color: TC.gray200))),
      child: Row(
        children: [
          if (showMenu)
            IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
          // Recherche : un numéro de demande ouvre les demandes, un nom ouvre les utilisateurs
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                style: TC.body,
                decoration: InputDecoration(
                  hintText: 'Rechercher une demande, un utilisateur…',
                  hintStyle: TC.muted,
                  prefixIcon: const Icon(Icons.search, size: 18, color: TC.gray600),
                  isDense: true,
                  filled: true,
                  fillColor: TC.gray100,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(TC.radiusMd),
                  ),
                ),
                onSubmitted: (q) {
                  final v = q.trim();
                  if (v.isEmpty) return;
                  final estNumero = RegExp(r'^(TC-?)?[\d-]+$', caseSensitive: false).hasMatch(v);
                  context.go(estNumero
                      ? Uri(path: '/demandes', queryParameters: {'numero': v}).toString()
                      : Uri(path: '/utilisateurs', queryParameters: {'nom': v}).toString());
                },
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: alertes > 0 ? '$alertes élément(s) à traiter' : 'Aucune alerte',
            child: InkWell(
              borderRadius: BorderRadius.circular(TC.radiusMd),
              onTap: () => context.go((stats['litiges_ouverts'] as int? ?? 0) > 0 ? '/litiges' : '/utilisateurs?onglet=kyc'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: TC.gray200),
                  borderRadius: BorderRadius.circular(TC.radiusMd),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none, size: 20, color: TC.gray900),
                    if (alertes > 0)
                      Positioned(
                        top: 10,
                        right: 11,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: TC.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: TC.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            tooltip: 'Compte',
            offset: const Offset(0, 52),
            onSelected: (_) => auth.logout(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Déconnexion'))),
            ],
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: TC.primary100, shape: BoxShape.circle),
                  child: Text(initiales,
                      style: GoogleFonts.poppins(color: TC.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                if (MediaQuery.sizeOf(context).width > 700) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom ?? 'Admin', style: TC.body.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
                      Text('Super-administrateur', style: TC.caption),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
