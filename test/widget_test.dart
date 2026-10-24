import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/riderpages/register/register.dart';
import 'package:rider_app/services/address_service.dart';
import 'package:rider_app/services/auth_service.dart';

/// A rider as `/api/rider/me` returns them after the station rejects them.
Map<String, dynamic> rejectedRider() => {
      'id': 7,
      'status': 'rejected',
      'status_reason': 'OR/CR plate does not match',
      'first_name': 'Juan',
      'last_name': 'Dela Cruz',
      'full_name': 'Juan Dela Cruz',
      'email': 'juan@example.com',
      'mobile': '9171234567',
      'birth_date': '1998-04-12',
      'province': {'code': 'NCR', 'name': 'Metro Manila (NCR)'},
      'city': {'code': '137404000', 'name': 'Quezon City'},
      'barangay': {'code': '137404001', 'name': 'Bagong Pag-asa'},
      'street': '12 Rizal St.',
      'vehicle_type': 'tricycle',
      'plate_number': 'NAB1234',
      'license_no': 'N01-23-456789',
      'license_expiry': '2028-05-15',
      'hub': {'id': '12', 'name': 'Quezon City Station', 'province': 'Metro Manila', 'city': 'Quezon City'},
      'applied_at': '2026-10-21T08:00:00+08:00',
    };

void main() {
  test('statuses from Picksell map to what the app shows', () {
    expect(RiderStatus.parse('active'), RiderStatus.active);
    expect(RiderStatus.parse('pending'), RiderStatus.pending);
    expect(RiderStatus.parse('under_review'), RiderStatus.pending);
    expect(RiderStatus.parse('rejected'), RiderStatus.rejected);
  });

  test('a rejected rider gets their application back to fix', () {
    final account = RiderAccount.fromJson(rejectedRider());
    final data = RegisterData.resubmission(account);

    expect(account.statusReason, 'OR/CR plate does not match');
    expect(data.isResubmission, isTrue);
    expect([data.firstName, data.lastName, data.mobile], ['Juan', 'Dela Cruz', '9171234567']);
    expect(data.province, PsgcPlace.metroManila);
    expect(data.city?.code, '137404000');
    expect(data.hub?.id, '12');
    expect(data.vehicleType, VehicleType.tricycle);
    expect(data.licenseExpiry, DateTime(2028, 5, 15));
    // Documents are attached again; the old files are replaced.
    expect(data.licenseFrontPath, isNull);
    expect(data.registrationPaths, isEmpty);
  });
}
