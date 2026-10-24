import 'package:dio/dio.dart';
import 'package:rider_app/services/address_service.dart';
import 'package:rider_app/services/api_client.dart';
import 'package:rider_app/services/auth_service.dart';

const int kRegisterTotalSteps = 5;

class RegisterData {
  RegisterData();

  /// Refills the form for a rejected rider who is fixing their application.
  /// Email and password stay as they are; documents must be attached again.
  factory RegisterData.resubmission(RiderAccount account) {
    final r = account.raw;
    final station = account.station;
    return RegisterData()
      ..isResubmission = true
      ..firstName = (r['first_name'] as String?) ?? ''
      ..lastName = (r['last_name'] as String?) ?? ''
      ..birthDate = DateTime.tryParse(r['birth_date'] as String? ?? '')
      ..mobile = (r['mobile'] as String?) ?? ''
      ..province = account.place('province')
      ..city = account.place('city')
      ..barangay = account.place('barangay')
      ..street = (r['street'] as String?) ?? ''
      ..email = account.email
      ..hub = station == null
          ? null
          : Hub(id: station.id, name: station.name, province: station.province ?? '', city: station.city)
      ..vehicleType = VehicleType.fromApi(r['vehicle_type'] as String?)
      ..plateNumber = (r['plate_number'] as String?) ?? ''
      ..licenseNo = (r['license_no'] as String?) ?? ''
      ..licenseExpiry = DateTime.tryParse(r['license_expiry'] as String? ?? '');
  }

  /// True when a rejected rider is resubmitting (signed in, no email step).
  bool isResubmission = false;

  // Step 1
  String firstName = '';
  String lastName = '';
  DateTime? birthDate;
  String mobile = '';
  PsgcPlace? province;
  PsgcPlace? city;
  PsgcPlace? barangay;
  String street = '';

  // Step 2
  String email = '';
  String password = '';
  String emailVerificationToken = '';

  // Step 3
  Hub? hub;
  VehicleType? vehicleType;

  // Step 4
  String plateNumber = '';
  String licenseNo = '';
  DateTime? licenseExpiry;
  String? licenseFrontPath;
  String? licenseBackPath;
  List<String> registrationPaths = [];
}

// ── Hub ───────────────────────────────────────────────────────────────────────

/// A Picksell station hub the rider can apply to.
class Hub {
  const Hub({required this.id, required this.name, required this.province, this.city});
  final String id;
  final String name;
  final String province;
  final String? city;

  factory Hub.fromJson(Map<String, dynamic> j) => Hub(
        id: j['id'].toString(),
        name: j['name'] as String,
        province: (j['province'] as String?) ?? '',
        city: j['city'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Hub && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// How far the station search had to go from the rider's address.
enum HubScope { city, province, none }

class NearbyHubs {
  const NearbyHubs(this.scope, this.hubs);
  final HubScope scope;
  final List<Hub> hubs;
}

abstract class HubService {
  /// Stations in the rider's city; if none, the rest of their province.
  Future<NearbyHubs> fetchNearby({required String cityCode, required String provinceCode});
}

class HttpHubService implements HubService {
  @override
  Future<NearbyHubs> fetchNearby({required String cityCode, required String provinceCode}) async {
    try {
      final res = await apiClient.get('/api/rider/stations',
          queryParameters: {'city_code': cityCode, 'province_code': provinceCode});
      final scope = switch (res.data['scope']) {
        'city' => HubScope.city,
        'province' => HubScope.province,
        _ => HubScope.none,
      };
      final list = res.data['hubs'] as List<dynamic>;
      return NearbyHubs(scope,
          list.map((e) => Hub.fromJson(Map<String, dynamic>.from(e as Map))).toList());
    } on DioException catch (e) {
      throw Exception(apiErrorMessage(e));
    }
  }
}

final HubService hubService = HttpHubService();

// ── VehicleType ───────────────────────────────────────────────────────────────

enum VehicleType {
  motorcycle('Motorcycle', 0xe5af),
  tricycle('Tricycle', 0xe556);

  const VehicleType(this.label, this.iconCodePoint);
  final String label;
  final int iconCodePoint;

  String get apiValue => switch (this) {
        VehicleType.motorcycle => 'motorcycle',
        VehicleType.tricycle   => 'tricycle',
      };

  static VehicleType? fromApi(String? value) => switch (value) {
        'motorcycle' => VehicleType.motorcycle,
        'tricycle' => VehicleType.tricycle,
        _ => null,
      };
}
