import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'api/api_client.dart';

/// Télécharge toutes les pages d'une collection et les enregistre en CSV (séparateur « ; », compatible Excel FR).
Future<int> exporterCsv(
  ApiClient api, {
  required String path,
  required String fichier,
  required Map<String, String Function(Map<String, dynamic>)> colonnes,
  Map<String, String> query = const {},
}) async {
  final lignes = <Map<String, dynamic>>[];
  for (var page = 1;; page++) {
    final p = await api.list(path, query: {...query, 'page': '$page'});
    lignes.addAll(p.items);
    if (p.items.isEmpty || lignes.length >= p.total) break;
  }

  String cellule(String v) => '"${v.replaceAll('"', '""')}"';
  final csv = StringBuffer()
    ..writeln(colonnes.keys.map(cellule).join(';'));
  for (final l in lignes) {
    csv.writeln(colonnes.values.map((f) => cellule(f(l))).join(';'));
  }

  // BOM UTF-8 pour qu'Excel lise correctement les accents
  final bytes = utf8.encode('﻿$csv');
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = url
    ..download = fichier
    ..click();
  web.URL.revokeObjectURL(url);
  return lignes.length;
}
