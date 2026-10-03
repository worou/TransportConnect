import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// API TransportConnect. Production par défaut ; autre cible :
/// `flutter build apk --dart-define=API_URL=https://…`
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://transco.teranga.re');

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Client JSON : jeton JWT en en-tête, renouvellement automatique sur 401.
class Api {
  Api({required this.onTokens, required this.onExpired});

  String? accessToken;
  String? refreshToken;
  final void Function(Map<String, dynamic> tokens) onTokens;
  final void Function() onExpired;

  final _http = http.Client();
  Future<bool>? _refreshing;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async =>
      await _send('GET', path, query: query) as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> list(String path, {Map<String, String>? query}) async =>
      (await _send('GET', path, query: query) as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = true}) async =>
      (await _send('POST', path, body: body, auth: auth)) as Map<String, dynamic>? ?? const {};

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async =>
      await _send('PATCH', path, body: body) as Map<String, dynamic>;

  /// Envoi d'une photo (JPEG) ; renvoie son URL publique.
  Future<String> upload(Uint8List bytes, String filename) async {
    Future<http.StreamedResponse> send() {
      final req = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/uploads'))
        ..headers['Accept'] = 'application/json'
        ..files.add(http.MultipartFile.fromBytes('fichier', bytes, filename: filename));
      if (accessToken != null) req.headers['Authorization'] = 'Bearer $accessToken';
      return _http.send(req);
    }

    var res = await http.Response.fromStream(await send());
    if (res.statusCode == 401 && await _refresh()) {
      res = await http.Response.fromStream(await send());
    }
    final json = _decode(res);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, _message(json, res.statusCode));
    return (json as Map)['url'] as String;
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Map<String, dynamic>? body, bool auth = true, bool retry = true}) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$apiUrl$path')
        .replace(queryParameters: (query == null || query.isEmpty) ? null : query);
    final req = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = method == 'PATCH' ? 'application/merge-patch+json' : 'application/json';
    if (auth && accessToken != null) req.headers['Authorization'] = 'Bearer $accessToken';
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req));
    } catch (_) {
      throw ApiException(0, 'Connexion impossible. Vérifiez votre accès internet.');
    }
    if (res.statusCode == 401 && auth && retry && refreshToken != null) {
      if (await _refresh()) return _send(method, path, query: query, body: body, retry: false);
      onExpired();
    }
    final json = _decode(res);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, _message(json, res.statusCode));
    return json;
  }

  Future<bool> _refresh() => _refreshing ??= () async {
        try {
          final t = await _send('POST', '/api/auth/refresh', body: {'refresh_token': refreshToken}, auth: false, retry: false)
              as Map<String, dynamic>;
          accessToken = t['access_token'] as String;
          refreshToken = t['refresh_token'] as String;
          onTokens(t);
          return true;
        } catch (_) {
          return false;
        } finally {
          _refreshing = null;
        }
      }();

  static dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  static String _message(dynamic json, int status) {
    if (json is Map) {
      final violations = json['violations'];
      if (violations is List && violations.isNotEmpty) return violations.map((v) => v['message']).join('\n');
      final d = json['detail'] ?? json['message'];
      if (d is String && d.isNotEmpty) return d;
    }
    return switch (status) {
      401 => 'Session expirée, reconnectez-vous.',
      403 => 'Action non autorisée.',
      404 => 'Élément introuvable.',
      429 => 'Trop de tentatives, réessayez plus tard.',
      _ => 'Erreur $status, réessayez.',
    };
  }
}

/// `/api/villes/4` → `4`
String idOf(String iri) => iri.substring(iri.lastIndexOf('/') + 1);
