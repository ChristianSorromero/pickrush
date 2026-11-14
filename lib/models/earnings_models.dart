/// The Earnings page, from `/api/rider/earnings`. A pickup or delivery earns
/// once it is done; failed attempts earn nothing.
library;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

class EarningsTotal {
  const EarningsTotal({required this.earnings, required this.pickups, required this.deliveries});
  final double earnings;
  final int pickups;
  final int deliveries;

  factory EarningsTotal.fromJson(Map<String, dynamic> j) => EarningsTotal(
        earnings: _d(j['earnings']),
        pickups: j['pickups'] as int,
        deliveries: j['deliveries'] as int,
      );
}

class EarningsDay extends EarningsTotal {
  const EarningsDay({required this.date, required super.earnings, required super.pickups, required super.deliveries});
  final DateTime date;

  factory EarningsDay.fromJson(Map<String, dynamic> j) => EarningsDay(
        date: DateTime.parse(j['date'] as String),
        earnings: _d(j['earnings']),
        pickups: j['pickups'] as int,
        deliveries: j['deliveries'] as int,
      );
}

class FinishedBatch {
  const FinishedBatch({
    required this.id,
    required this.batchNo,
    required this.isDelivery,
    required this.parcels,
    required this.earned,
    this.completedAt,
  });

  final int id;
  final String batchNo;
  final bool isDelivery;
  final int parcels;
  final double earned;
  final DateTime? completedAt;

  factory FinishedBatch.fromJson(Map<String, dynamic> j) => FinishedBatch(
        id: j['id'] as int,
        batchNo: j['batch_no'] as String,
        isDelivery: j['type'] == 'delivery',
        parcels: j['parcels'] as int,
        earned: _d(j['earned']),
        completedAt: DateTime.tryParse(j['completed_at'] as String? ?? '')?.toLocal(),
      );
}

/// The station's count of the cash the rider handed over, waiting for the
/// rider to confirm it or reject it so it is counted again.
class PendingCashCount {
  const PendingCashCount({
    required this.id,
    required this.expected,
    required this.counted,
    required this.difference,
    required this.payKept,
    this.countedBy,
    this.at,
  });

  final int id;

  /// What the system says the rider should hand over.
  final double expected;

  /// What the station staff counted.
  final double counted;

  /// counted - expected: negative means the station counted less.
  final double difference;
  final double payKept;
  final String? countedBy;
  final DateTime? at;

  factory PendingCashCount.fromJson(Map<String, dynamic> j) => PendingCashCount(
        id: j['id'] as int,
        expected: _d(j['expected']),
        counted: _d(j['counted']),
        difference: _d(j['difference']),
        payKept: _d(j['pay_kept']),
        countedBy: j['counted_by'] as String?,
        at: DateTime.tryParse(j['at'] as String? ?? '')?.toLocal(),
      );
}

class CodSummary {
  const CodSummary({
    required this.inHand,
    required this.limit,
    required this.remittedThisMonth,
    this.pendingCount,
    this.lastAmount,
    this.lastAt,
    this.lastStatus,
  });

  /// Cash collected and not yet handed to the station.
  final double inHand;
  final double limit;
  final double remittedThisMonth;

  /// A station count the rider still has to confirm or reject.
  final PendingCashCount? pendingCount;
  final double? lastAmount;
  final DateTime? lastAt;

  /// awaiting_rider (the rider has not answered the count yet), reconciled,
  /// or disputed (the counted cash did not match).
  final String? lastStatus;

  factory CodSummary.fromJson(Map<String, dynamic> j) {
    final last = j['last_remittance'] is Map ? Map<String, dynamic>.from(j['last_remittance'] as Map) : null;
    return CodSummary(
      inHand: _d(j['in_hand']),
      limit: _d(j['limit']),
      remittedThisMonth: _d(j['remitted_this_month']),
      pendingCount: j['pending_count'] is Map
          ? PendingCashCount.fromJson(Map<String, dynamic>.from(j['pending_count'] as Map))
          : null,
      lastAmount: last == null ? null : _d(last['amount']),
      lastAt: last == null ? null : DateTime.tryParse(last['at'] as String? ?? '')?.toLocal(),
      lastStatus: last?['status'] as String?,
    );
  }
}

/// What one parcel class pays, pickup or delivery: [pay], plus [perKgPay]
/// for each started kg above [aboveKg] (EXTRA_BULKY).
class ClassRule {
  const ClassRule({required this.code, required this.aboveKg, required this.upToKg, required this.pay, this.perKgPay = 0});

  final String code;
  final double aboveKg;
  final double upToKg;
  final double pay;
  final double perKgPay;

  factory ClassRule.fromJson(Map<String, dynamic> j) => ClassRule(
        code: j['code'] as String,
        aboveKg: _d(j['above_kg']),
        upToKg: _d(j['up_to_kg']),
        pay: _d(j['pay']),
        perKgPay: _d(j['per_kg_pay']),
      );
}

class EarningsData {
  const EarningsData({
    required this.pickupRate,
    required this.deliveryRate,
    this.classRates = const {},
    this.classRules = const [],
    required this.today,
    required this.week,
    required this.month,
    required this.days,
    required this.batches,
    required this.cod,
  });

  final double pickupRate;
  final double deliveryRate;

  /// Base pay by parcel class (STANDARD, HEAVY, BULKY, EXTRA_BULKY), lightest first.
  final Map<String, double> classRates;

  /// Pickup and delivery pay by weight, lightest first (empty from older servers).
  final List<ClassRule> classRules;
  final EarningsTotal today;
  final EarningsTotal week;
  final EarningsTotal month;

  /// The last 7 days, oldest first; the last one is today.
  final List<EarningsDay> days;
  final List<FinishedBatch> batches;
  final CodSummary cod;

  factory EarningsData.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object? v) => Map<String, dynamic>.from(v as Map);
    final rates = m(j['rates']);
    return EarningsData(
      pickupRate: _d(rates['pickup']),
      deliveryRate: _d(rates['delivery']),
      classRates: rates['classes'] is Map
          ? {for (final e in m(rates['classes']).entries) e.key: _d(e.value)}
          : const {},
      classRules: rates['class_rules'] is List
          ? [for (final r in rates['class_rules'] as List) ClassRule.fromJson(m(r))]
          : const [],
      today: EarningsTotal.fromJson(m(j['today'])),
      week: EarningsTotal.fromJson(m(j['week'])),
      month: EarningsTotal.fromJson(m(j['month'])),
      days: [for (final d in j['days'] as List) EarningsDay.fromJson(m(d))],
      batches: [for (final b in j['batches'] as List) FinishedBatch.fromJson(m(b))],
      cod: CodSummary.fromJson(m(j['cod'])),
    );
  }
}
