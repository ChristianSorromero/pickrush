import 'package:dio/dio.dart';
import 'package:rider_app/services/address_service.dart';
import 'package:rider_app/services/api_client.dart';

const int kRegisterTotalSteps = 5;

class RegisterData {
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
  String vehicleModel = '';
  String plateNumber = '';

  // Step 4
  String? licenseFrontPath;
  String? licenseBackPath;
  List<String> registrationPaths = [];
}

// ── Hub ───────────────────────────────────────────────────────────────────────

class Hub {
  const Hub({required this.id, required this.name, required this.province});
  final String id;
  final String name;
  final String province;

  factory Hub.fromJson(Map<String, dynamic> j) => Hub(
        id: j['id'] as String,
        name: j['name'] as String,
        province: j['province'] as String,
      );

  @override
  bool operator ==(Object other) => other is Hub && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

abstract class HubService {
  Future<List<Hub>> fetchHubs();
}

class HttpHubService implements HubService {
  @override
  Future<List<Hub>> fetchHubs() async {
    try {
      final res = await apiClient.get('/api/hubs');
      final list = res.data as List<dynamic>;
      return list.map((e) => Hub.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(apiErrorMessage(e));
    }
  }
}

final HubService hubService = HttpHubService();

// ── VehicleType ───────────────────────────────────────────────────────────────

enum VehicleType {
  motorcycle('Motorcycle', 0xe5af),
  car('Car', 0xe1b9),
  tricycle('Tricycle', 0xe556),
  bicycleOther('Bicycle / Other', 0xe2dc);

  const VehicleType(this.label, this.iconCodePoint);
  final String label;
  final int iconCodePoint;

  bool get needsPlate => this != VehicleType.bicycleOther;

  String get apiValue => switch (this) {
        VehicleType.motorcycle   => 'motorcycle',
        VehicleType.car          => 'car',
        VehicleType.tricycle     => 'tricycle',
        VehicleType.bicycleOther => 'bicycle_other',
      };
}
