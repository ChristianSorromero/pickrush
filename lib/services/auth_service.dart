import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rider_app/services/address_service.dart';
import 'package:rider_app/services/api_client.dart';

// ── Rider account ─────────────────────────────────────────────────────────────

/// Where the rider is in onboarding. Only [active] riders get parcels.
enum RiderStatus {
  pending,
  active,
  rejected,
  suspended,
  deactivated;

  /// `under_review` comes from Picksell's older two-person check; it is still
  /// an application waiting for the station.
  static RiderStatus parse(String? value) => switch (value) {
        'active' => RiderStatus.active,
        'rejected' => RiderStatus.rejected,
        'suspended' => RiderStatus.suspended,
        'deactivated' => RiderStatus.deactivated,
        _ => RiderStatus.pending,
      };
}

class RiderStation {
  const RiderStation({required this.id, required this.name, this.city, this.province});
  final String id;
  final String name;
  final String? city;
  final String? province;

  factory RiderStation.fromJson(Map<String, dynamic> j) => RiderStation(
        id: j['id'].toString(),
        name: j['name'] as String,
        city: j['city'] as String?,
        province: j['province'] as String?,
      );
}

/// The signed-in rider as returned by `/api/rider/me`.
class RiderAccount {
  const RiderAccount({
    required this.id,
    required this.status,
    required this.raw,
    this.statusReason,
    this.station,
  });

  final int id;
  final RiderStatus status;
  final String? statusReason;
  final RiderStation? station;

  /// The full profile, used to refill the form when a rejected rider resubmits.
  final Map<String, dynamic> raw;

  String get fullName => (raw['full_name'] as String?) ?? '';
  String get email => (raw['email'] as String?) ?? '';
  DateTime? get appliedAt => DateTime.tryParse(raw['applied_at'] as String? ?? '')?.toLocal();
  DateTime? get approvedAt => DateTime.tryParse(raw['approved_at'] as String? ?? '')?.toLocal();

  // Account page (read-only: the station keeps these) -------------------------
  String get firstName => (raw['first_name'] as String?) ?? fullName.split(' ').first;
  String? get mobile => raw['mobile'] as String?;
  bool get isOnline => raw['shift_status'] == 'on_shift';
  bool get onProbation => raw['on_probation'] == true;
  String? get zone => raw['zone'] as String?;
  double? get codLimit => (raw['cod_limit'] as num?)?.toDouble();
  int? get maxParcels => raw['max_parcels'] as int?;
  String? get vehicleType => raw['vehicle_type'] as String?;
  String? get plateNumber => raw['plate_number'] as String?;
  String? get licenseNo => raw['license_no'] as String?;
  DateTime? get licenseExpiry => DateTime.tryParse(raw['license_expiry'] as String? ?? '');

  /// Street, barangay, city, province as the rider applied with them.
  String get fullAddress => [
        raw['street'],
        place('barangay')?.name,
        place('city')?.name,
        place('province')?.name,
      ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  /// gcash, maya or bank, and the account with all but the last 4 digits hidden.
  ({String method, String? account})? get payout {
    final p = raw['payout'];
    if (p is! Map) return null;
    return (method: p['method'] as String, account: p['account'] as String?);
  }

  ({String name, String? mobile})? get emergencyContact {
    final e = raw['emergency_contact'];
    if (e is! Map) return null;
    return (name: e['name'] as String, mobile: e['mobile'] as String?);
  }

  ({String name, String? mobile})? get stationContact {
    final e = raw['station_contact'];
    if (e is! Map) return null;
    return (name: e['name'] as String, mobile: e['mobile'] as String?);
  }

  List<RiderDocumentInfo> get documents => [
        for (final d in (raw['documents'] as List? ?? const []))
          RiderDocumentInfo(
            label: (d as Map)['label'] as String,
            side: d['side'] as String?,
            expiry: DateTime.tryParse(d['expiry'] as String? ?? ''),
          ),
      ];

  PsgcPlace? place(String key) {
    final p = raw[key];
    if (p is! Map) return null;
    return PsgcPlace(code: p['code'] as String, name: p['name'] as String);
  }

  factory RiderAccount.fromJson(Map<String, dynamic> j) => RiderAccount(
        id: j['id'] as int,
        status: RiderStatus.parse(j['status'] as String?),
        statusReason: j['status_reason'] as String?,
        station: j['hub'] is Map
            ? RiderStation.fromJson(Map<String, dynamic>.from(j['hub'] as Map))
            : null,
        raw: j,
      );
}

/// A document the rider applied with (license front/back, OR/CR).
class RiderDocumentInfo {
  const RiderDocumentInfo({required this.label, this.side, this.expiry});
  final String label;
  final String? side;
  final DateTime? expiry;

  String get title => side == null ? label : '$label (${side![0].toUpperCase()}${side!.substring(1)})';

  /// Days until it expires (negative: expired), or null when it has no expiry.
  int? daysLeft([DateTime? today]) {
    if (expiry == null) return null;
    final now = today ?? DateTime.now();
    return DateTime(expiry!.year, expiry!.month, expiry!.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }
}

class AuthException implements Exception {
  AuthException(this.message, {this.signedOut = false});
  final String message;

  /// The token is gone or no longer valid; the rider must log in again.
  final bool signedOut;

  @override
  String toString() => message;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Email and password sign-in against Picksell's rider API.
/// The token is kept in secure storage when the rider chooses "Remember me".
class AuthService {
  static const _tokenKey = 'rider_token';
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? get token => _token;
  bool get isSignedIn => _token != null;

  /// Loads a remembered token. Returns true when one was found.
  Future<bool> restore() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    return _token != null;
  }

  Future<RiderAccount> login(String email, String password,
      {bool remember = true}) async {
    try {
      final res = await apiClient.post('/api/rider/login',
          data: {'email': email.trim(), 'password': password});
      _token = res.data['token'] as String;
      if (remember) {
        await _storage.write(key: _tokenKey, value: _token);
      } else {
        await _storage.delete(key: _tokenKey);
      }
      return RiderAccount.fromJson(
          Map<String, dynamic>.from(res.data['rider'] as Map));
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  Future<RiderAccount> me() async {
    try {
      final res = await apiClient.get('/api/rider/me');
      return RiderAccount.fromJson(
          Map<String, dynamic>.from(res.data['rider'] as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _forget();
        throw AuthException('Please log in again.', signedOut: true);
      }
      throw AuthException(apiErrorMessage(e));
    }
  }

  /// "Forgot password?": emails a code to the registered address. Returns it
  /// masked (e.g. ch•••••••23@gmail.com) to show the rider where to look.
  Future<String> forgotPassword(String email) async {
    try {
      final res = await apiClient.post('/api/rider/password/forgot', data: {'email': email.trim()});
      return (res.data['masked_email'] as String?) ?? email.trim();
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  /// The emailed code plus a new password. Every phone is signed out.
  Future<void> resetPassword(String email, String code, String password, String confirm) async {
    try {
      await apiClient.post('/api/rider/password/reset', data: {
        'email': email.trim(),
        'code': code,
        'password': password,
        'password_confirmation': confirm,
      });
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  /// Change password; other phones signed in to this account are signed out.
  Future<void> changePassword(String current, String next, String confirm) async {
    try {
      await apiClient.post('/api/rider/password', data: {
        'current_password': current,
        'password': next,
        'password_confirmation': confirm,
      });
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e), signedOut: e.response?.statusCode == 401);
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) await apiClient.post('/api/rider/logout');
    } catch (_) {
      // Signing out locally is enough if the server can't be reached.
    }
    await _forget();
  }

  Future<void> _forget() async {
    _token = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }
}

final AuthService authService = AuthService();
