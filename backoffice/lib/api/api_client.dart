import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL de l'API : `flutter run -d chrome --dart-define=API_URL=https://api.exemple.com`
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Page d'une collection Hydra (JSON-LD).
class ApiPage {
  ApiPage(this.items, this.total);

  final List<Map<String, dynamic>> items;
  final int total;
}

/// Client HTTP de l'API TransportConnect : JWT en en-tête, renouvellement automatique sur 401.
class ApiClient {
  ApiClient({required this.onTokensRefreshed, required this.onSessionExpired});

  String? accessToken;
  String? refreshToken;

  /// Appelé quand /api/auth/refresh a fourni de nouveaux jetons (à persister).
  final void Function(Map<String, dynamic> tokens) onTokensRefreshed;

  /// Appelé quand le refresh token n'est plus valable : retour à l'écran de connexion.
  final void Function() onSessionExpired;

  final _http = http.Client();
  Future<bool>? _refreshing;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async =>
      (await _send('GET', path, query: query)) as Map<String, dynamic>;

  Future<ApiPage> list(String path, {Map<String, String>? query}) async {
    final json = await get(path, query: query);
    final items = (json['member'] as List? ?? const []).cast<Map<String, dynamic>>();
    return ApiPage(items, (json['totalItems'] as num?)?.toInt() ?? items.length);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = true}) async =>
      (await _send('POST', path, body: body, auth: auth)) as Map<String, dynamic>? ?? const {};

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async =>
      (await _send('PATCH', path, body: body)) as Map<String, dynamic>;

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
    bool retry = true,
  }) async {
    final uri = Uri.parse('$apiUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/ld+json'
      ..headers['Content-Type'] = method == 'PATCH' ? 'application/merge-patch+json' : 'application/ld+json';
    if (auth && accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } catch (_) {
      throw ApiException(0, "Impossible de joindre l'API ($apiUrl).");
    }

    if (response.statusCode == 401 && auth && retry && refreshToken != null) {
      if (await _refresh()) {
        return _send(method, path, query: query, body: body, retry: false);
      }
      onSessionExpired();
    }

    final text = utf8.decode(response.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _message(json, response.statusCode));
    }
    return json;
  }

  /// Un seul renouvellement à la fois, même si plusieurs requêtes reçoivent 401 en parallèle.
  Future<bool> _refresh() => _refreshing ??= () async {
        try {
          final tokens = await _send('POST', '/api/auth/refresh',
              body: {'refresh_token': refreshToken}, auth: false, retry: false) as Map<String, dynamic>;
          accessToken = tokens['access_token'] as String;
          refreshToken = tokens['refresh_token'] as String;
          onTokensRefreshed(tokens);
          return true;
        } catch (_) {
          return false;
        } finally {
          _refreshing = null;
        }
      }();

  static String _message(dynamic json, int status) {
    if (json is Map) {
      final violations = json['violations'];
      if (violations is List && violations.isNotEmpty) {
        return violations.map((v) => v['message']).join('\n');
      }
      final detail = json['detail'] ?? json['description'] ?? json['message'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    return switch (status) {
      401 => 'Session expirée, reconnectez-vous.',
      403 => 'Action non autorisée.',
      404 => 'Ressource introuvable.',
      _ => 'Erreur $status',
    };
  }
}

/// `/api/utilisateurs/40000…` → `40000…`
String idFromIri(String iri) => iri.substring(iri.lastIndexOf('/') + 1);
