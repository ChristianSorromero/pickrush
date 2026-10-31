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

class CodSummary {
  const CodSummary({
    required this.inHand,
    required this.limit,
    required this.remittedThisMonth,
    this.lastAmount,
    this.lastAt,
    this.lastStatus,
  });

  /// Cash collected and not yet handed to the station.
  final double inHand;
  final double limit;
  final double remittedThisMonth;
  final double? lastAmount;
  final DateTime? lastAt;

  /// reconciled, or disputed (the counted cash did not match).
  final String? lastStatus;

  factory CodSummary.fromJson(Map<String, dynamic> j) {
    final last = j['last_remittance'] is Map ? Map<String, dynamic>.from(j['last_remittance'] as Map) : null;
    return CodSummary(
      inHand: _d(j['in_hand']),
      limit: _d(j['limit']),
      remittedThisMonth: _d(j['remitted_this_month']),
      lastAmount: last == null ? null : _d(last['amount']),
      lastAt: last == null ? null : DateTime.tryParse(last['at'] as String? ?? '')?.toLocal(),
      lastStatus: last?['status'] as String?,
    );
  }
}

class EarningsData {
  const EarningsData({
    required this.pickupRate,
    required this.deliveryRate,
    required this.today,
    required this.week,
    required this.month,
    required this.days,
    required this.batches,
    required this.cod,
  });

  final double pickupRate;
  final double deliveryRate;
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
      today: EarningsTotal.fromJson(m(j['today'])),
      week: EarningsTotal.fromJson(m(j['week'])),
      month: EarningsTotal.fromJson(m(j['month'])),
      days: [for (final d in j['days'] as List) EarningsDay.fromJson(m(d))],
      batches: [for (final b in j['batches'] as List) FinishedBatch.fromJson(m(b))],
      cod: CodSummary.fromJson(m(j['cod'])),
    );
  }
}
