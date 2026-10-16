import 'dart:convert';

import 'package:http/http.dart' as http;

/// A province, city/municipality or barangay from the PSGC API.
/// [code] is used to fetch the next level down; [name] is what's displayed.
class PsgcPlace {
  const PsgcPlace({required this.code, required this.name});

  final String code;
  final String name;

  /// PSGC has no "province" for the NCR, so the app adds this entry itself
  /// and loads the NCR's cities directly by region.
  static const metroManila = PsgcPlace(code: 'NCR', name: 'Metro Manila (NCR)');
  bool get isMetroManila => code == metroManila.code;

  factory PsgcPlace.fromJson(Map<String, dynamic> json) => PsgcPlace(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) => other is PsgcPlace && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => name;
}

class PsgcException implements Exception {
  PsgcException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Province → City/Municipality → Barangay lookups.
/// Wraps https://psgc.gitlab.io/api (free, no API key, full lists, no paging).
/// Results are cached in memory for the lifetime of the service.
class PsgcService {
  PsgcService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://psgc.gitlab.io/api';
  static const _ncrRegionCode = '130000000';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final Map<String, List<PsgcPlace>> _cache = {};

  void dispose() => _client.close();

  Future<List<PsgcPlace>> provinces() async {
    final list = [
      ...await _getList('/provinces/'),
      PsgcPlace.metroManila,
    ];
    return _sorted(list);
  }

  Future<List<PsgcPlace>> citiesOf(PsgcPlace province) {
    return _getList(province.isMetroManila
        ? '/regions/$_ncrRegionCode/cities-municipalities/'
        : '/provinces/${province.code}/cities-municipalities/');
  }

  Future<List<PsgcPlace>> barangaysOf(PsgcPlace city) {
    return _getList('/cities-municipalities/${city.code}/barangays/');
  }

  // ── internals ──────────────────────────────────────────────────────────────

  Future<List<PsgcPlace>> _getList(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;

    final http.Response res;
    try {
      res = await _client.get(Uri.parse('$_baseUrl$path')).timeout(_timeout);
    } catch (_) {
      throw PsgcException(
          'Could not reach the address service. Check your connection.');
    }
    if (res.statusCode != 200) {
      throw PsgcException('Address service error (${res.statusCode}).');
    }

    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      final list = _sorted(data
          .map((e) => PsgcPlace.fromJson(e as Map<String, dynamic>))
          .toList());
      _cache[path] = list;
      return list;
    } catch (_) {
      throw PsgcException('Unexpected response from the address service.');
    }
  }

  List<PsgcPlace> _sorted(List<PsgcPlace> list) => list
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}