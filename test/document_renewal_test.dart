import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/riderpages/register/register_shared.dart';
import 'package:rider_app/services/auth_service.dart';

void main() {
  test('the account reads the OR/CR expiry, renewals and what blocks the rider', () {
    final account = RiderAccount.fromJson({
      'id': 7,
      'status': 'active',
      'orcr_expiry': '2027-11-15',
      'blocked_by_document': "Driver's license",
      'documents': [
        {'type': 'or_cr', 'label': 'OR/CR (vehicle registration)', 'expiry': '2027-11-15', 'expiry_estimated': true},
      ],
      'document_updates': [
        {'type': 'drivers_license', 'label': "Driver's license", 'status': 'pending', 'expiry': '2030-01-31', 'sent_at': '2026-11-15T08:00:00+08:00'},
        {'type': 'or_cr', 'label': 'OR/CR', 'status': 'rejected', 'reason': 'Blurry photo.', 'expiry': '2027-06-30'},
      ],
    });

    expect(account.orcrExpiry, DateTime(2027, 11, 15));
    expect(account.blockedByDocument, "Driver's license");
    expect(account.documents.single.expiryEstimated, isTrue);
    expect(account.updateFor('drivers_license')!.isPending, isTrue);
    expect(account.updateFor('or_cr')!.reason, 'Blurry photo.');
    expect(RiderAccount.fromJson({'id': 1, 'status': 'active'}).documentUpdates, isEmpty, reason: 'older servers send none');
  });

  test('an OR/CR expiry must be a real date, today or later', () {
    final now = DateTime.now();
    String day(DateTime d) => formatExpiryInput(d);

    expect(validateOrcrExpiry(''), 'Enter the registration expiry on your OR');
    expect(validateOrcrExpiry('2026-02-30'), 'Enter a valid date (YYYY-MM-DD)');
    expect(validateOrcrExpiry(day(now.subtract(const Duration(days: 1)))), 'Your vehicle registration is expired. Renew it first.');
    expect(validateOrcrExpiry(day(now)), isNull);
  });
}
