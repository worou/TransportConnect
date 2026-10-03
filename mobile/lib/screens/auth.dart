import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

const _pays = {
  '+229': 'BJ +229',
  '+228': 'TG +228',
  '+225': 'CI +225',
  '+221': 'SN +221',
  '+226': 'BF +226',
  '+227': 'NE +227',
  '+33': 'FR +33',
};

/// M02 — Connexion : espace (marchand / représentant) et numéro de téléphone.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _espace = 'marchand';
  String _indicatif = '+229';
  final _numero = TextEditingController();
  bool _busy = false;

  /// Format international : en France le 0 initial disparaît (06… → +336…), ailleurs le numéro est gardé tel quel.
  String get _telephone {
    final chiffres = _numero.text.replaceAll(RegExp(r'\D'), '');
    return _indicatif + (_indicatif == '+33' ? chiffres.replaceFirst(RegExp(r'^0'), '') : chiffres);
  }

  Future<void> _envoyer() async {
    if (_numero.text.replaceAll(RegExp(r'\D'), '').length < 8) {
      toast(context, 'Saisissez un numéro de téléphone valide.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await context.session.sendOtp(_telephone);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(telephone: _telephone, espace: _espace, otpId: r.otpId, codeDev: r.codeDev),
      ));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), children: [
                const Align(alignment: Alignment.centerLeft, child: TcLogo(height: 24, fontSize: 22)),
                const SizedBox(height: 36),
                Text('Bienvenue', style: TC.h1),
                const SizedBox(height: 8),
                Text('Entrez votre numéro pour recevoir un code de connexion.', style: TC.bodyMuted.copyWith(fontSize: 16)),
                const SizedBox(height: 24),
                Text('Je suis', style: TC.label),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _RoleTile(icon: Icons.inventory_2_outlined, titre: 'Marchand', texte: "J'expédie des marchandises", selected: _espace == 'marchand', onTap: () => setState(() => _espace = 'marchand'))),
                  const SizedBox(width: 12),
                  Expanded(child: _RoleTile(icon: Icons.local_shipping_outlined, titre: 'Représentant', texte: "J'évalue pour un transporteur", selected: _espace == 'representant', onTap: () => setState(() => _espace = 'representant'))),
                ]),
                const SizedBox(height: 20),
                Text('Numéro de téléphone', style: TC.label),
                const SizedBox(height: 6),
                Container(
                  height: 52,
                  decoration: BoxDecoration(color: TC.white, borderRadius: BorderRadius.circular(TC.radius), border: Border.all(color: TC.primary, width: 2)),
                  child: Row(children: [
                    Container(
                      color: TC.ground,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _indicatif,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: TC.ink),
                          items: [for (final e in _pays.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                          onChanged: (v) => setState(() => _indicatif = v!),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _numero,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
                        style: GoogleFonts.inter(fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: '97 12 34 56',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        onSubmitted: (_) => _busy ? null : _envoyer(),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Text('Un SMS avec un code à 6 chiffres vous sera envoyé.', style: TC.caption),
                if (_espace == 'representant') ...[
                  const SizedBox(height: 16),
                  const InfoBox('Les comptes représentant sont créés par votre transporteur. Utilisez le numéro qu\'il a enregistré.', icon: Icons.info_outline),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(children: [
                FilledButton(
                  onPressed: _busy ? null : _envoyer,
                  child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: TC.white)) : const Text('Recevoir le code'),
                ),
                const SizedBox(height: 10),
                Text("En continuant, vous acceptez les conditions d'utilisation et la politique de confidentialité de TransportConnect.",
                    textAlign: TextAlign.center, style: TC.caption),
              ]),
            ),
          ]),
        ),
      );
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.icon, required this.titre, required this.texte, required this.selected, required this.onTap});

  final IconData icon;
  final String titre;
  final String texte;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? TC.primary100 : TC.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? TC.primary : TC.border, width: selected ? 2 : 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 104),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: selected ? TC.primary : TC.ink),
                const SizedBox(height: 8),
                Text(titre, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: selected ? TC.primary : TC.ink)),
                const SizedBox(height: 2),
                Text(texte, style: TC.caption.copyWith(color: selected ? TC.ink : TC.muted)),
              ]),
            ),
          ),
        ),
      );
}

/// M03 — Code de vérification à 6 chiffres.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.telephone, required this.espace, required this.otpId, this.codeDev});

  final String telephone;
  final String espace;
  final String otpId;
  final String? codeDev;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late String _otpId = widget.otpId;
  late String? _codeDev = widget.codeDev;
  int _attente = 60;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _demarrerMinuteur();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _demarrerMinuteur() {
    _timer?.cancel();
    setState(() => _attente = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_attente <= 1) t.cancel();
      if (mounted) setState(() => _attente--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _renvoyer() async {
    try {
      final r = await context.session.sendOtp(widget.telephone);
      setState(() {
        _otpId = r.otpId;
        _codeDev = r.codeDev;
        _code.clear();
      });
      _demarrerMinuteur();
      if (mounted) toast(context, 'Nouveau code envoyé.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _valider() async {
    if (_code.text.length != 6) return;
    setState(() => _busy = true);
    try {
      await context.session.verifyOtp(_otpId, _code.text, widget.espace);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message, error: true);
      _code.clear();
      if (e.status == 403 || e.status == 429 || e.message.contains('expiré')) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _attente ~/ 60, s = (_attente % 60).toString().padLeft(2, '0');
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: ''),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), children: [
              Text('Code de vérification', style: TC.h1),
              const SizedBox(height: 8),
              Text.rich(TextSpan(style: TC.bodyMuted.copyWith(fontSize: 16), children: [
                const TextSpan(text: 'Saisissez le code envoyé au '),
                TextSpan(text: widget.telephone, style: const TextStyle(color: TC.ink, fontWeight: FontWeight.w700)),
              ])),
              const SizedBox(height: 24),
              _OtpBoxes(controller: _code, focus: _focus, onChanged: (_) {
                setState(() {});
                if (_code.text.length == 6 && !_busy) _valider();
              }),
              if (_codeDev != null) ...[
                const SizedBox(height: 10),
                Text('Version de test — code : $_codeDev', style: TC.caption.copyWith(color: const Color(0xFF9A5B0B))),
              ],
              const SizedBox(height: 18),
              Row(children: [
                const Icon(Icons.schedule, size: 16, color: TC.muted),
                const SizedBox(width: 8),
                if (_attente > 0)
                  Text.rich(TextSpan(style: TC.small.copyWith(fontSize: 14), children: [
                    const TextSpan(text: 'Renvoyer le code dans '),
                    TextSpan(text: '$m:$s', style: const TextStyle(color: TC.ink, fontWeight: FontWeight.w700)),
                  ]))
                else
                  TextButton(onPressed: _renvoyer, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Renvoyer le code')),
              ]),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => Navigator.of(context).maybePop(), style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Modifier le numéro')),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(children: [
              const InfoBox('Après 3 essais incorrects, demandez un nouveau code.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || _code.text.length != 6 ? null : _valider,
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: TC.white)) : const Text('Valider'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 6 cases visuelles au-dessus d'un champ unique (collage et remplissage automatique pris en charge).
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({required this.controller, required this.focus, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 6; i++)
            Container(
              width: 48,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TC.white,
                borderRadius: BorderRadius.circular(TC.radius),
                border: Border.all(
                  color: i == controller.text.length ? TC.primary : TC.border,
                  width: i == controller.text.length ? 2 : 1.5,
                ),
              ),
              child: Text(i < controller.text.length ? controller.text[i] : '',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: TC.ink)),
            ),
        ]),
        Positioned.fill(
          child: Opacity(
            opacity: 0.01,
            child: TextField(
              controller: controller,
              focusNode: focus,
              maxLength: 6,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              showCursor: false,
              decoration: const InputDecoration(counterText: '', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
              onChanged: onChanged,
            ),
          ),
        ),
      ]);
}
