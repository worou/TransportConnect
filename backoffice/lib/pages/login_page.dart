import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Connexion administrateur : numéro de téléphone puis code OTP à 6 chiffres.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController(text: '+229');
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  String? _otpId;
  String? _codeDev;
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.message;
      // Code inutilisable (compte non admin, expiré, trop d'essais) : retour à la saisie du numéro
      if (_otpId != null && (e.status == 403 || e.status == 429 || e.message.contains('expiré'))) {
        _otpId = null;
        _codeDev = null;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendOtp() => _run(() async {
        final r = await AuthScope.of(context).sendOtp(_phone.text.replaceAll(' ', ''));
        _otpId = r.otpId;
        _codeDev = r.codeDev;
        _code.clear();
        // Le champ du code apparaît au prochain rendu : on lui donne le focus ensuite
        WidgetsBinding.instance.addPostFrameCallback((_) => _codeFocus.requestFocus());
      });

  Future<void> _verify() => _run(() => AuthScope.of(context).verifyOtp(_otpId!, _code.text));

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TC.primary900,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TcCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: TC.secondary, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.local_shipping, color: TC.white),
                        ),
                        const SizedBox(width: 12),
                        Text('TransConnect Admin', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(_otpId == null ? 'Connexion' : 'Code de vérification', style: TC.h2),
                    const SizedBox(height: 4),
                    Text(
                      _otpId == null
                          ? 'Saisissez le numéro de votre compte administrateur.'
                          : 'Entrez le code à 6 chiffres envoyé par SMS au ${_phone.text}.',
                      style: TC.body.copyWith(color: TC.gray500),
                    ),
                    const SizedBox(height: 24),
                    if (_otpId == null)
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
                        onSubmitted: (_) => _busy ? null : _sendOtp(),
                      )
                    else ...[
                      TextField(
                        controller: _code,
                        focusNode: _codeFocus,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.inter(fontSize: 26, letterSpacing: 14, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                        onSubmitted: (_) => _busy ? null : _verify(),
                      ),
                      if (_codeDev != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Mode développement — code : $_codeDev',
                              style: TC.caption.copyWith(color: TC.secondary700)),
                        ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TC.body.copyWith(color: TC.error)),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _busy ? null : (_otpId == null ? _sendOtp : _verify),
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: TC.white))
                          : Text(_otpId == null ? 'RECEVOIR LE CODE' : 'SE CONNECTER'),
                    ),
                    if (_otpId != null)
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _otpId = null),
                        child: const Text('Changer de numéro'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
