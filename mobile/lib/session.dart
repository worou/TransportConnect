import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Session : jetons conservés sur le téléphone, profil de l'utilisateur connecté, référentiel des villes.
class Session extends ChangeNotifier {
  Session() {
    api = Api(onTokens: _save, onExpired: logout);
  }

  late final Api api;
  Map<String, dynamic>? me;
  List<Map<String, dynamic>> villes = const [];
  bool ready = false;

  String get role => me?['role'] as String? ?? '';
  String get meIri => '/api/utilisateurs/${me?['id']}';

  static const _kA = 'tc_access', _kR = 'tc_refresh';

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    api.accessToken = p.getString(_kA);
    api.refreshToken = p.getString(_kR);
    if (api.refreshToken != null) {
      try {
        await _load();
      } catch (_) {
        await _clear();
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<({String otpId, String? codeDev})> sendOtp(String tel) async {
    final r = await api.post('/api/auth/send-otp', {'telephone': tel}, auth: false);
    return (otpId: r['otp_id'] as String, codeDev: r['code_dev'] as String?);
  }

  /// [espace] : « marchand » ou « representant » (l'API refuse un numéro d'un autre rôle).
  Future<bool> verifyOtp(String otpId, String code, String espace) async {
    final t = await api.post('/api/auth/verify-otp', {'otp_id': otpId, 'code': code, 'espace': espace}, auth: false);
    api.accessToken = t['access_token'] as String;
    api.refreshToken = t['refresh_token'] as String;
    await _save(t);
    await _load();
    notifyListeners();
    return t['nouveau_compte'] == true;
  }

  Future<void> reloadMe() async {
    me = await api.get('/api/me');
    notifyListeners();
  }

  Future<void> logout() async {
    final r = api.refreshToken;
    await _clear();
    notifyListeners();
    if (r != null) {
      try {
        await api.post('/api/auth/logout', {'refresh_token': r}, auth: false);
      } catch (_) {}
    }
  }

  Map<String, dynamic>? ville(String? iri) {
    if (iri == null) return null;
    for (final v in villes) {
      if ('/api/villes/${v['id']}' == iri) return v;
    }
    return null;
  }

  Future<void> _load() async {
    me = await api.get('/api/me');
    villes = await api.list('/api/villes', query: {'est_couverte': 'true'});
  }

  Future<void> _save(Map<String, dynamic> t) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kA, t['access_token'] as String);
    await p.setString(_kR, t['refresh_token'] as String);
  }

  Future<void> _clear() async {
    me = null;
    api.accessToken = null;
    api.refreshToken = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kA);
    await p.remove(_kR);
  }
}

class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);

  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

extension SessionContext on BuildContext {
  Session get session => SessionScope.of(this);
  Api get api => SessionScope.of(this).api;
}
