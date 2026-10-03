import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Session administrateur : connexion par OTP, jetons conservés dans le navigateur.
class AuthController extends ChangeNotifier {
  AuthController() {
    api = ApiClient(onTokensRefreshed: _saveTokens, onSessionExpired: logout);
  }

  late final ApiClient api;
  Map<String, dynamic>? user;
  bool ready = false;

  bool get isLoggedIn => user != null;
  String get userIri => user?['@id'] as String? ?? '';

  static const _kAccess = 'tc_access_token';
  static const _kRefresh = 'tc_refresh_token';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    api.accessToken = prefs.getString(_kAccess);
    api.refreshToken = prefs.getString(_kRefresh);
    if (api.refreshToken != null) {
      try {
        await _loadProfile();
      } catch (_) {
        await _clear();
      }
    }
    ready = true;
    notifyListeners();
  }

  /// Étape 1 : renvoie l'otp_id et, en développement (OTP_DEBUG=1), le code.
  Future<({String otpId, String? codeDev})> sendOtp(String telephone) async {
    final r = await api.post('/api/auth/send-otp', {'telephone': telephone}, auth: false);
    return (otpId: r['otp_id'] as String, codeDev: r['code_dev'] as String?);
  }

  /// Étape 2 : seuls les comptes administrateur accèdent au back-office.
  Future<void> verifyOtp(String otpId, String code) async {
    // « espace: admin » : l'API refuse les numéros sans compte admin, sans créer de compte marchand
    final tokens = await api.post('/api/auth/verify-otp', {'otp_id': otpId, 'code': code, 'espace': 'admin'}, auth: false);
    if (tokens['role'] != 'admin') {
      await api.post('/api/auth/logout', {'refresh_token': tokens['refresh_token']}, auth: false);
      throw ApiException(403, 'Accès réservé aux administrateurs de la plateforme.');
    }
    api.accessToken = tokens['access_token'] as String;
    api.refreshToken = tokens['refresh_token'] as String;
    await _saveTokens(tokens);
    await _loadProfile();
    notifyListeners();
  }

  /// Compteurs de la barre latérale (comptes et KYC à valider, litiges ouverts, commission, villes).
  Map<String, dynamic>? stats;

  Future<void> refreshStats() async {
    try {
      stats = await api.get('/api/admin/tableau-de-bord');
      notifyListeners();
    } catch (_) {
      // Les compteurs sont secondaires : on garde les précédents.
    }
  }

  Future<void> logout() async {
    final refresh = api.refreshToken;
    await _clear();
    notifyListeners();
    if (refresh != null) {
      try {
        await api.post('/api/auth/logout', {'refresh_token': refresh}, auth: false);
      } catch (_) {}
    }
  }

  Future<void> _loadProfile() async {
    final me = await api.get('/api/me');
    if (me['role'] != 'admin') {
      throw ApiException(403, 'Accès réservé aux administrateurs.');
    }
    user = me;
  }

  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, tokens['access_token'] as String);
    await prefs.setString(_kRefresh, tokens['refresh_token'] as String);
  }

  Future<void> _clear() async {
    user = null;
    api.accessToken = null;
    api.refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }
}
