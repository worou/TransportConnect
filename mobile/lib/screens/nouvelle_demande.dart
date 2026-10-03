import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'suivi.dart';

/// M05 → M07 : nouvelle demande en 4 étapes (trajet, marchandise, contact, récapitulatif).
class NouvelleDemandeScreen extends StatefulWidget {
  const NouvelleDemandeScreen({super.key});

  @override
  State<NouvelleDemandeScreen> createState() => _NouvelleDemandeScreenState();
}

class _NouvelleDemandeScreenState extends State<NouvelleDemandeScreen> {
  int _etape = 1;
  bool _busy = false;

  // Étape 1 – trajet
  String? _villeDepart;
  String? _villeArrivee;
  final _adresseDepart = TextEditingController();
  final _adresseArrivee = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  Position? _position;
  bool _localisation = false;

  // Étape 2 – marchandise
  String _type = 'standard';
  final _description = TextEditingController();
  final _poids = TextEditingController();
  final _volume = TextEditingController();
  String _urgence = 'normale';
  final List<(Uint8List, String)> _photos = [];

  // Étape 3 – contact
  late final _contactNom = TextEditingController(text: context.session.me?['nom_complet'] as String? ?? '');
  late final _contactTel = TextEditingController(text: context.session.me?['telephone'] as String? ?? '');
  final _instructions = TextEditingController();

  static const _titres = {1: 'Trajet', 2: 'Marchandise', 3: 'Contact sur place', 4: 'Vérification'};

  Map<String, dynamic>? get _vd => context.session.ville(_villeDepart);
  Map<String, dynamic>? get _va => context.session.ville(_villeArrivee);

  /// Distance routière estimée : vol d'oiseau entre les deux villes × 1,25, arrondie au km.
  double? get _distanceKm {
    final a = _vd, b = _va;
    if (a == null || b == null || a['latitude'] == null || b['latitude'] == null) return null;
    final m = distanceMetres(double.parse('${a['latitude']}'), double.parse('${a['longitude']}'), double.parse('${b['latitude']}'), double.parse('${b['longitude']}'));
    return (m / 1000 * 1.25).roundToDouble().clamp(1, 5000);
  }

  String? _erreurEtape() {
    switch (_etape) {
      case 1:
        if (_villeDepart == null || _villeArrivee == null) return 'Choisissez les villes de départ et d\'arrivée.';
        if (_villeDepart == _villeArrivee) return 'La ville d\'arrivée doit être différente du départ.';
        if (_adresseDepart.text.trim().isEmpty || _adresseArrivee.text.trim().isEmpty) return 'Indiquez les quartiers ou adresses.';
      case 2:
        if (_description.text.trim().isEmpty) return 'Décrivez la marchandise.';
        if (_num(_poids.text) == null && _num(_volume.text) == null) return 'Indiquez au moins le poids ou le volume.';
      case 3:
        if (_contactNom.text.trim().isEmpty || _contactTel.text.trim().isEmpty) return 'Indiquez la personne à contacter sur place.';
    }
    return null;
  }

  static double? _num(String s) {
    final v = double.tryParse(s.replaceAll(' ', '').replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  void _suivant() {
    final e = _erreurEtape();
    if (e != null) {
      toast(context, e, error: true);
      return;
    }
    setState(() => _etape++);
  }

  Future<void> _localiser(bool on) async {
    if (!on) {
      setState(() {
        _localisation = false;
        _position = null;
      });
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) toast(context, 'Autorisez la localisation pour utiliser votre position.', error: true);
        return;
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      setState(() {
        _position = p;
        _localisation = true;
      });
    } catch (_) {
      if (mounted) toast(context, 'Position introuvable. Activez la localisation du téléphone.', error: true);
    }
  }

  Future<void> _ajouterPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Prendre une photo'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _photos.add((bytes, f.name.isEmpty ? 'photo.jpg' : f.name)));
  }

  Future<void> _confirmer() async {
    setState(() => _busy = true);
    final api = context.api, session = context.session;
    try {
      final d = await api.post('/api/demandes', {
        'marchand': session.meIri,
        'ville_depart': _villeDepart,
        'ville_arrivee': _villeArrivee,
        'adresse_depart': _adresseDepart.text.trim(),
        'adresse_arrivee': _adresseArrivee.text.trim(),
        'type_marchandise': _type,
        'description': _description.text.trim(),
        if (_num(_poids.text) != null) 'poids_estime': '${_num(_poids.text)}',
        if (_num(_volume.text) != null) 'volume_estime': '${_num(_volume.text)}',
        'date_enlevement': DateFormat('yyyy-MM-dd').format(_date),
        'urgence': _urgence,
        'contact_nom': _contactNom.text.trim(),
        'contact_telephone': _contactTel.text.trim(),
        if (_instructions.text.trim().isNotEmpty) 'instructions': _instructions.text.trim(),
        if (_distanceKm != null) 'distance_km': '$_distanceKm',
        if (_position != null) 'lat_depart': _position!.latitude.toStringAsFixed(6),
        if (_position != null) 'lng_depart': _position!.longitude.toStringAsFixed(6),
      });
      // Photos facultatives : un échec n'annule pas la demande, déjà créée
      var echecs = 0;
      for (final (bytes, nom) in _photos) {
        try {
          final url = await api.upload(bytes, nom);
          await api.post('/api/photos', {'url': url, 'contexte': 'demande', 'demande': '/api/demandes/${d['id']}'});
        } on ApiException {
          echecs++;
        }
      }
      if (!mounted) return;
      toast(context, echecs == 0 ? 'Demande ${d['numero']} enregistrée.' : 'Demande enregistrée ; $echecs photo(s) non envoyée(s).');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SuiviDemandeScreen(id: d['id'] as String)));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _etape == 1,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _etape--);
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(children: [
              TopBar(title: _etape == 4 ? 'Récapitulatif' : 'Nouvelle demande'),
              StepsBar(step: _etape, total: 4, label: _titres[_etape]!),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: switch (_etape) {
                  1 => _trajet(),
                  2 => _marchandise(),
                  3 => _contact(),
                  _ => _recap(),
                }),
              ),
              BottomActions(children: [
                if (_etape > 1 && _etape < 4) OutlinedButton(onPressed: () => setState(() => _etape--), child: const Text('Retour')),
                if (_etape < 4)
                  FilledButton(onPressed: _suivant, child: const Text('Continuer'))
                else
                  FilledButton(
                    onPressed: _busy ? null : _confirmer,
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: TC.white)) : const Text('Confirmer la demande'),
                  ),
              ]),
            ]),
          ),
        ),
      );

  Widget _villeChamp(String label, String? value, ValueChanged<String?> onChanged) => LabeledField(
        label: label,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          hint: const Text('Choisir une ville'),
          items: [
            for (final v in context.session.villes) DropdownMenuItem(value: '/api/villes/${v['id']}', child: Text('${v['nom_ville']}')),
          ],
          onChanged: onChanged,
        ),
      );

  List<Widget> _trajet() {
    final demain = DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
    final apresDemain = demain.add(const Duration(days: 1));
    final choisie = DateUtils.dateOnly(_date);
    return [
      _villeChamp('Ville de départ', _villeDepart, (v) => setState(() => _villeDepart = v)),
      const SizedBox(height: 14),
      LabeledField(
        label: 'Quartier / adresse de départ',
        child: TextField(controller: _adresseDepart, decoration: const InputDecoration(hintText: 'Ex : Akpakpa, rue 12', prefixIcon: Icon(Icons.place_outlined))),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _localisation,
        onChanged: _localiser,
        title: Text('Je suis sur le lieu d\'enlèvement', style: TC.label),
        subtitle: Text(_position == null ? 'Votre position aide le représentant à vous trouver.' : 'Position enregistrée (précision ${_position!.accuracy.round()} m).',
            style: TC.caption),
      ),
      const SizedBox(height: 8),
      _villeChamp("Ville d'arrivée", _villeArrivee, (v) => setState(() => _villeArrivee = v)),
      const SizedBox(height: 14),
      LabeledField(
        label: "Quartier / adresse d'arrivée",
        child: TextField(controller: _adresseArrivee, decoration: const InputDecoration(hintText: 'Ex : Centre-ville, marché Arzèkè', prefixIcon: Icon(Icons.place_outlined))),
      ),
      const SizedBox(height: 18),
      Text("Date souhaitée d'enlèvement", style: TC.label),
      const SizedBox(height: 8),
      ChoiceGrid(
        options: {
          'demain': 'Demain',
          'apres': DateFormat('EEEE', 'fr_FR').format(apresDemain).replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase()),
          'autre': choisie != demain && choisie != apresDemain ? date(choisie.toIso8601String()) : 'Autre date',
        },
        value: choisie == demain ? 'demain' : (choisie == apresDemain ? 'apres' : 'autre'),
        onChanged: (v) async {
          if (v == 'demain') return setState(() => _date = demain);
          if (v == 'apres') return setState(() => _date = apresDemain);
          final d = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: demain,
            lastDate: DateTime.now().add(const Duration(days: 90)),
            locale: const Locale('fr', 'FR'),
          );
          if (d != null) setState(() => _date = d);
        },
      ),
    ];
  }

  List<Widget> _marchandise() => [
        Text('Type de marchandise', style: TC.label),
        const SizedBox(height: 8),
        ChoiceGrid(options: Statuts.types, value: _type, onChanged: (v) => setState(() => _type = v)),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Description',
          child: TextField(
            controller: _description,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Ex : 20 sacs de riz de 50 kg, bien fermés'),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: LabeledField(
              label: 'Poids (kg)',
              child: TextField(controller: _poids, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]'))]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LabeledField(
              label: 'Volume (m³)',
              child: TextField(controller: _volume, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]'))]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Urgence', style: TC.label),
        const SizedBox(height: 8),
        Segmented(options: const {'normale': 'Normale', 'express': 'Express'}, value: _urgence, onChanged: (v) => setState(() => _urgence = v)),
        const SizedBox(height: 16),
        Text.rich(TextSpan(style: TC.label, children: [
          const TextSpan(text: 'Photos '),
          TextSpan(text: '(facultatif, 5 max)', style: TC.small.copyWith(fontSize: 14)),
        ])),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < _photos.length; i++)
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_photos[i].$1, width: 72, height: 72, fit: BoxFit.cover)),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => setState(() => _photos.removeAt(i)),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close, size: 16, color: TC.white),
                  ),
                ),
              ),
            ]),
          if (_photos.length < 5)
            InkWell(
              onTap: _ajouterPhoto,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: TC.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7B4C2), width: 1.5)),
                child: const Icon(Icons.photo_camera_outlined, color: TC.primary),
              ),
            ),
        ]),
      ];

  List<Widget> _contact() => [
        Text("La personne qui accueillera le représentant au lieu d'enlèvement.", style: TC.bodyMuted),
        const SizedBox(height: 16),
        LabeledField(label: 'Nom du contact', child: TextField(controller: _contactNom, textCapitalization: TextCapitalization.words)),
        const SizedBox(height: 14),
        LabeledField(label: 'Téléphone du contact', child: TextField(controller: _contactTel, keyboardType: TextInputType.phone)),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Instructions (facultatif)',
          child: TextField(controller: _instructions, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'Ex : appeler en arrivant, portail bleu')),
        ),
      ];

  List<Widget> _recap() {
    final km = _distanceKm;
    Widget ligne(String titre, String valeur, int etape) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: TC.small),
                const SizedBox(height: 2),
                Text(valeur, style: TC.strong),
              ]),
            ),
            IconButton(tooltip: 'Modifier', onPressed: () => setState(() => _etape = etape), icon: const Icon(Icons.edit_outlined, size: 20, color: TC.primary)),
          ]),
        );
    final quantite = [
      if (_num(_poids.text) != null) '${nombre(_num(_poids.text)!)} kg',
      if (_num(_volume.text) != null) '${_volume.text.trim()} m³',
    ].join(' · ');
    return [
      Panel(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Column(children: [
          ligne('Trajet', '${_vd?['nom_ville']} (${_adresseDepart.text.trim()}) → ${_va?['nom_ville']} (${_adresseArrivee.text.trim()})', 1),
          const Divider(height: 1),
          ligne('Enlèvement souhaité', DateFormat('EEEE dd/MM/yyyy', 'fr_FR').format(_date), 1),
          const Divider(height: 1),
          ligne('Marchandise', '${Statuts.types[_type]} · ${_description.text.trim()}', 2),
          const Divider(height: 1),
          ligne('Quantité', quantite, 2),
          const Divider(height: 1),
          ligne('Urgence', _urgence == 'express' ? 'Express' : 'Normale', 2),
          if (_photos.isNotEmpty) ...[const Divider(height: 1), ligne('Photos', '${_photos.length} photo(s)', 2)],
          const Divider(height: 1),
          ligne('Contact sur place', '${_contactNom.text.trim()} · ${_contactTel.text.trim()}', 3),
        ]),
      ),
      if (km != null) ...[
        const SizedBox(height: 12),
        Text('Distance estimée : environ ${nombre(km)} km', style: TC.small),
      ],
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: TC.primary100, borderRadius: BorderRadius.circular(TC.radius)),
        child: Row(children: [
          const Icon(Icons.schedule, color: TC.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(TextSpan(style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: TC.ink), children: const [
              TextSpan(text: 'Un représentant transporteur viendra évaluer la marchandise '),
              TextSpan(text: 'sous 24 h', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' et vous proposera un prix.'),
            ])),
          ),
        ]),
      ),
    ];
  }
}
