import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// R04 → R06 : évaluation sur site (check-in GPS, marchandise réelle et photos, prix).
/// Reprend à la bonne étape si le représentant revient plus tard.
class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key, required this.evaluationId});

  final String evaluationId;

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  Map<String, dynamic>? _e;
  Map<String, dynamic>? _d;
  Map<String, dynamic>? _grille;
  List<String> _vehicules = [];
  List<Map<String, dynamic>> _photos = [];
  Object? _erreur;
  int _etape = 1;
  bool _busy = false;

  // Étape 1
  Position? _position;
  String? _erreurGps;

  // Étape 2
  final _poids = TextEditingController();
  final _volume = TextEditingController();
  String _emballage = 'bon';
  final _contraintes = TextEditingController();

  // Étape 3
  int? _prix;
  final _justification = TextEditingController();
  int _delai = 2;
  String? _vehicule;

  String get _iri => '/api/evaluations/${widget.evaluationId}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_e == null && _erreur == null) _load();
  }

  Future<void> _load() async {
    final s = context.session;
    try {
      final e = await s.api.get(_iri);
      final r = await Future.wait([
        s.api.get(e['demande'] as String),
        s.api.list('/api/grille_tarifaires', query: {'transporteur': '${s.me!['transporteur']}', 'actif': 'true'}),
        s.api.list('/api/vehicules', query: {'transporteur': '${s.me!['transporteur']}', 'actif': 'true'}),
        s.api.list('/api/photos', query: {'evaluation': _iri}),
      ]);
      final d = r[0] as Map<String, dynamic>;
      final grilles = r[1] as List<Map<String, dynamic>>;
      setState(() {
        _e = e;
        _d = d;
        _grille = grilles.isEmpty ? null : grilles.first;
        _vehicules = {for (final v in r[2] as List<Map<String, dynamic>>) v['type_vehicule'] as String}.toList();
        _vehicule ??= _vehicules.firstOrNull;
        _photos = r[3] as List<Map<String, dynamic>>;
        _etape = e['date_checkin'] == null ? 1 : (e['date_soumission'] == null ? 2 : 3);
        if (_poids.text.isEmpty) _poids.text = '${e['poids_reel'] ?? d['poids_estime'] ?? ''}'.replaceAll('.00', '');
        if (_volume.text.isEmpty) _volume.text = '${e['volume_reel'] ?? d['volume_estime'] ?? ''}'.replaceAll('.00', '');
        final km = d['distance_km'] == null ? 300 : double.parse('${d['distance_km']}');
        _delai = (km / 300).ceil().clamp(1, 10);
      });
      if (_etape == 1) _localiser();
    } catch (e) {
      setState(() => _erreur = e);
    }
  }

  // ------------------------------------------------------------------------------------------------ étape 1 : check-in

  double? get _distance {
    final d = _d, p = _position;
    if (d == null || p == null || d['lat_depart'] == null) return null;
    return distanceMetres(p.latitude, p.longitude, double.parse('${d['lat_depart']}'), double.parse('${d['lng_depart']}'));
  }

  Future<void> _localiser() async {
    setState(() {
      _erreurGps = null;
      _position = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _erreurGps = 'Activez la localisation du téléphone.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _erreurGps = 'Autorisez la localisation pour faire le check-in.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
      if (mounted) setState(() => _position = p);
    } catch (_) {
      if (mounted) setState(() => _erreurGps = 'Position introuvable. Réessayez à l\'extérieur.');
    }
  }

  Future<void> _checkin() async {
    final p = _position!;
    final dist = _distance;
    setState(() => _busy = true);
    final ok = await act(context, () async {
      _e = await context.api.patch(_iri, {
        'date_checkin': DateTime.now().toUtc().toIso8601String(),
        'lat_checkin': p.latitude.toStringAsFixed(6),
        'lng_checkin': p.longitude.toStringAsFixed(6),
        // Distance connue seulement si le marchand a fourni sa position ; sinon rien n'est inventé
        'distance_checkin_m': dist?.round(),
      });
    });
    setState(() {
      _busy = false;
      if (ok) _etape = 2;
    });
  }

  // ------------------------------------------------------------------------------------------------ étape 2 : marchandise

  static double? _num(String s) {
    final v = double.tryParse(s.replaceAll(' ', '').replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _photo() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
    if (f == null || !mounted) return;
    setState(() => _busy = true);
    final api = context.api;
    await act(context, () async {
      final url = await api.upload(await f.readAsBytes(), f.name.isEmpty ? 'evaluation.jpg' : f.name);
      final photo = await api.post('/api/photos', {'url': url, 'contexte': 'evaluation', 'evaluation': _iri});
      setState(() => _photos = [..._photos, photo]);
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _soumettre() async {
    if (_num(_poids.text) == null) return toast(context, 'Indiquez le poids réel.', error: true);
    if (_photos.length < 2) return toast(context, 'Prenez au moins 2 photos de la marchandise.', error: true);
    setState(() => _busy = true);
    final ok = await act(context, () async {
      _e = await context.api.patch(_iri, {
        'poids_reel': '${_num(_poids.text)}',
        if (_num(_volume.text) != null) 'volume_reel': '${_num(_volume.text)}',
        'etat_emballage': _emballage,
        'contraintes': _contraintes.text.trim().isEmpty ? null : _contraintes.text.trim(),
        'date_soumission': DateTime.now().toUtc().toIso8601String(),
      });
    });
    setState(() {
      _busy = false;
      if (ok) _etape = 3;
    });
  }

  // ------------------------------------------------------------------------------------------------ étape 3 : prix

  /// Même calcul que la fonction SQL calculer_prix_suggere : (base + km × tarif + kg × tarif) × coef + express, à la centaine.
  ({double base, double km, double kg, double coef, double express, int total})? get _calcul {
    final g = _grille, d = _d, e = _e;
    if (g == null || d == null || e == null || d['distance_km'] == null) return null;
    double n(Object? v) => v == null ? 0 : double.parse('$v');
    final poids = e['poids_reel'] != null ? n(e['poids_reel']) : n(d['poids_estime']);
    final base = n(g['prix_base']), km = n(d['distance_km']) * n(g['tarif_km']), kg = poids * n(g['tarif_kg']);
    final coef = n((g['coef_type_marchandise'] as Map?)?[d['type_marchandise']] ?? 1);
    final express = d['urgence'] == 'express' ? n(g['supplement_express']) : 0.0;
    final total = (((base + km + kg) * coef + express) / 100).round() * 100;
    return (base: base, km: km, kg: kg, coef: coef, express: express, total: total);
  }

  Future<void> _envoyerDevis() async {
    final c = _calcul!;
    final prix = _prix ?? c.total;
    if (prix != c.total && _justification.text.trim().isEmpty) {
      return toast(context, 'Justifiez l\'ajustement du prix.', error: true);
    }
    setState(() => _busy = true);
    final ok = await act(
      context,
      () => context.api.post('/api/devis', {
        'evaluation': _iri,
        'grille': '/api/grille_tarifaires/${_grille!['id']}',
        if (prix != c.total) 'prix_propose': prix,
        if (prix != c.total) 'justification': _justification.text.trim(),
        'delai_jours': _delai,
        'type_vehicule': ?_vehicule,
      }),
      success: 'Prix envoyé au marchand.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------------------------------------ affichage

  @override
  Widget build(BuildContext context) {
    if (_erreur != null) {
      return Scaffold(
        body: SafeArea(child: Column(children: [const TopBar(title: 'Évaluation sur site'), Expanded(child: Center(child: Text('$_erreur', style: TC.bodyMuted)))])),
      );
    }
    if (_e == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final titres = {1: 'Check-in GPS', 2: 'Marchandise réelle', 3: 'Prix'};
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: _etape == 3 ? 'Proposition du prix' : 'Évaluation sur site', subtitle: '${_d!['numero']}'),
          StepsBar(step: _etape, total: 3, label: titres[_etape]!),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: switch (_etape) {
              1 => _vueCheckin(),
              2 => _vueMarchandise(),
              _ => _vuePrix(),
            }),
          ),
          BottomActions(children: switch (_etape) {
            1 => [
                FilledButton(
                  onPressed: _busy || _position == null ? null : _checkin,
                  child: _busy ? _spinner : const Text('Commencer l\'évaluation'),
                ),
              ],
            2 => [FilledButton(onPressed: _busy ? null : _soumettre, child: _busy ? _spinner : const Text('Continuer'))],
            _ => [
                FilledButton(
                  onPressed: _busy || _calcul == null ? null : _envoyerDevis,
                  child: _busy ? _spinner : const Text('Envoyer au marchand'),
                ),
              ],
          }),
        ]),
      ),
    );
  }

  static const _spinner = SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: TC.white));

  List<Widget> _vueCheckin() {
    final d = _d!;
    final dist = _distance;
    final surPlace = dist == null || dist <= 100;
    return [
      Panel(
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: _position == null ? TC.primary100 : (surPlace ? TC.successBg : const Color(0xFFFDEDEB)), shape: BoxShape.circle),
            child: Icon(
              _position == null ? Icons.gps_not_fixed : (surPlace ? Icons.where_to_vote : Icons.wrong_location_outlined),
              size: 36,
              color: _position == null ? TC.primary : (surPlace ? TC.success : TC.error),
            ),
          ),
          const SizedBox(height: 12),
          if (_erreurGps != null) ...[
            Text(_erreurGps!, textAlign: TextAlign.center, style: TC.strong.copyWith(color: TC.error)),
            TextButton(onPressed: _localiser, child: const Text('Réessayer')),
          ] else if (_position == null) ...[
            Text('Recherche de votre position…', style: TC.strong),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ] else ...[
            Text(
              dist == null ? 'Position relevée' : (surPlace ? 'Vous êtes sur place' : 'Vous êtes à ${nombre(dist.round())} m de l\'adresse'),
              style: TC.h3,
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (dist != null && surPlace) 'À ${dist.round()} m de l\'adresse',
                if (dist == null) 'Le marchand n\'a pas fourni sa position GPS',
                'précision ${_position!.accuracy.round()} m',
              ].join(' · '),
              textAlign: TextAlign.center,
              style: TC.small,
            ),
            TextButton(onPressed: _localiser, child: const Text('Actualiser la position')),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Adresse d'enlèvement", style: TC.caption),
          Text('${d['adresse_depart']}, ${d['nom_ville_depart']}', style: TC.strong),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openMaps(d['lat_depart'] != null ? '${d['lat_depart']},${d['lng_depart']}' : '${d['adresse_depart']}, ${d['nom_ville_depart']}'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: const Text('Itinéraire'),
              ),
            ),
            if ((d['contact_telephone'] ?? d['telephone_marchand']) != null) ...[
              const SizedBox(width: 10),
              SquareButton(icon: Icons.phone_outlined, tooltip: 'Appeler le contact', onPressed: () => appeler('${d['contact_telephone'] ?? d['telephone_marchand']}')),
            ],
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      const InfoBox('Le check-in est obligatoire : il horodate votre passage et sert de preuve en cas de litige. Il doit être fait à moins de 100 m du lieu d\'enlèvement.'),
    ];
  }

  List<Widget> _vueMarchandise() {
    final d = _d!;
    final declare = [
      if (d['poids_estime'] != null) '${nombre(num.parse('${d['poids_estime']}'))} kg',
      if (d['volume_estime'] != null) '${d['volume_estime']} m³',
    ].join(' · ');
    final num_ = [FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]'))];
    return [
      InfoBox('Déclaré par le marchand : ${Statuts.types[d['type_marchandise']]} · $declare\n${d['description']}', icon: Icons.inventory_2_outlined),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: LabeledField(label: 'Poids réel (kg)', child: TextField(controller: _poids, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: num_))),
        const SizedBox(width: 12),
        Expanded(child: LabeledField(label: 'Volume réel (m³)', child: TextField(controller: _volume, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: num_))),
      ]),
      const SizedBox(height: 16),
      Text("État de l'emballage", style: TC.label),
      const SizedBox(height: 8),
      ChoiceGrid(options: const {'bon': 'Bon', 'moyen': 'Moyen', 'mauvais': 'Mauvais'}, value: _emballage, onChanged: (v) => setState(() => _emballage = v)),
      const SizedBox(height: 16),
      LabeledField(
        label: 'Contraintes particulières',
        child: TextField(controller: _contraintes, maxLines: 3, decoration: const InputDecoration(hintText: 'Ex : 2 sacs légèrement déchirés, à protéger')),
      ),
      const SizedBox(height: 16),
      Text.rich(TextSpan(style: TC.label, children: [
        const TextSpan(text: 'Photos '),
        TextSpan(text: '· 2 minimum', style: TC.small.copyWith(fontSize: 14, color: _photos.length >= 2 ? TC.success : TC.muted)),
      ])),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final p in _photos)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network('${p['url']}', width: 72, height: 72, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: TC.segment, child: const Icon(Icons.check, color: TC.success))),
          ),
        InkWell(
          onTap: _busy ? null : _photo,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: TC.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7B4C2), width: 1.5)),
            child: _busy ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_outlined, color: TC.primary),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _vuePrix() {
    final c = _calcul;
    if (_grille == null) return [const InfoBox('Aucune grille tarifaire active pour votre transporteur : contactez votre administrateur.', icon: Icons.warning_amber)];
    if (c == null) return [const InfoBox('Distance de la demande inconnue : le prix ne peut pas être calculé.', icon: Icons.warning_amber)];
    final d = _d!;
    final prix = _prix ?? c.total;
    final min = (c.total * 0.8 / 100).ceil() * 100, max = (c.total * 1.2 / 100).floor() * 100;
    final ecart = (prix - c.total) / c.total * 100;
    Widget ligne(String label, num v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [Expanded(child: Text(label, style: TC.bodyMuted)), Text(fcfa(v.round()), style: TC.body)]),
        );
    return [
      Panel(
        child: Column(children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline, color: TC.secondary, size: 18),
            const SizedBox(width: 6),
            Text('Prix suggéré · calcul automatique', style: TC.small),
          ]),
          const SizedBox(height: 6),
          Text(fcfa(c.total).replaceAll(' F', ' FCFA'), style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w700, color: TC.ink)),
          const Divider(height: 20),
          ligne('Prix de base', c.base),
          ligne('Distance (${nombre(num.parse('${d['distance_km']}'))} km)', c.km),
          ligne('Poids (${nombre(num.parse('${_e!['poids_reel']}'))} kg)', c.kg),
          if (c.coef != 1) ligne('${Statuts.types[d['type_marchandise']]} (×${'${c.coef}'.replaceAll('.', ',')})', (c.base + c.km + c.kg) * (c.coef - 1)),
          if (c.express > 0) ligne('Express', c.express),
        ]),
      ),
      const SizedBox(height: 16),
      Text.rich(TextSpan(style: TC.label, children: [
        const TextSpan(text: 'Ajuster le prix '),
        TextSpan(text: '(facultatif, ±20 %)', style: TC.small.copyWith(fontSize: 14)),
      ])),
      const SizedBox(height: 8),
      Row(children: [
        SquareButton(icon: Icons.remove, tooltip: 'Baisser de 500 F', onPressed: prix - 500 < min ? null : () => setState(() => _prix = prix - 500)),
        Expanded(
          child: Column(children: [
            Text(fcfa(prix).replaceAll(' F', ' FCFA'), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: TC.ink)),
            Text(prix == c.total ? 'Prix suggéré' : '${ecart > 0 ? '+' : '−'}${ecart.abs().toStringAsFixed(1).replaceAll('.', ',')} %', style: TC.small),
          ]),
        ),
        SquareButton(icon: Icons.add, tooltip: 'Augmenter de 500 F', onPressed: prix + 500 > max ? null : () => setState(() => _prix = prix + 500)),
      ]),
      const SizedBox(height: 4),
      Row(children: [Text('Min ${fcfa(min)}', style: TC.caption), const Spacer(), Text('Max ${fcfa(max)}', style: TC.caption)]),
      if (prix != c.total) ...[
        const SizedBox(height: 12),
        LabeledField(
          label: 'Justification (obligatoire si modifié)',
          child: TextField(controller: _justification, maxLines: 2, decoration: const InputDecoration(hintText: 'Ex : emballage à renforcer avant chargement')),
        ),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: LabeledField(
            label: 'Délai (jours)',
            child: Row(children: [
              SquareButton(icon: Icons.remove, tooltip: 'Moins', onPressed: _delai <= 1 ? null : () => setState(() => _delai--)),
              Expanded(child: Text('$_delai', textAlign: TextAlign.center, style: TC.h3)),
              SquareButton(icon: Icons.add, tooltip: 'Plus', onPressed: _delai >= 15 ? null : () => setState(() => _delai++)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        if (_vehicules.isNotEmpty)
          Expanded(
            child: LabeledField(
              label: 'Véhicule',
              child: DropdownButtonFormField<String>(
                initialValue: _vehicule,
                isExpanded: true,
                items: [for (final v in _vehicules) DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _vehicule = v),
              ),
            ),
          ),
      ]),
    ];
  }
}

