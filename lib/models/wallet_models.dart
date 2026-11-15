/// The rider wallet, from `/api/rider/earnings` (`wallet`) and
/// `/api/rider/payslips`. Every pickup, delivery and return goes to the
/// wallet; each week (Monday to Sunday) closes into a payslip on Sunday night,
/// and once the station releases it (by Tuesday) its net can be withdrawn.
/// Withdrawals are simulated for now: paid at once with a mock reference.
library;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

DateTime? _at(Object? v) => DateTime.tryParse(v as String? ?? '')?.toLocal();

Map<String, dynamic> _m(Object? v) => Map<String, dynamic>.from(v as Map);

/// Taken off the rider's pay: cash short at a remittance, or a parcel the
/// rider damaged or lost.
class WalletDeduction {
  const WalletDeduction({
    required this.id,
    required this.kind,
    required this.label,
    required this.amount,
    required this.reason,
    required this.status,
    required this.canDispute,
    this.trackingNo,
    this.at,
    this.disputeReason,
    this.decisionNote,
  });

  final int id;

  /// shortage, damage, lost or other.
  final String kind;
  final String label;
  final double amount;
  final String reason;

  /// active, disputed (waiting for the station manager) or waived.
  final String status;

  /// The rider can still dispute it: active and its payslip not released yet.
  final bool canDispute;
  final String? trackingNo;
  final DateTime? at;
  final String? disputeReason;
  final String? decisionNote;

  bool get isDisputed => status == 'disputed';

  factory WalletDeduction.fromJson(Map<String, dynamic> j) => WalletDeduction(
        id: j['id'] as int,
        kind: j['kind'] as String,
        label: j['label'] as String,
        amount: _d(j['amount']),
        reason: j['reason'] as String,
        status: j['status'] as String,
        canDispute: j['can_dispute'] as bool? ?? false,
        trackingNo: j['tracking_no'] as String?,
        at: _at(j['at']),
        disputeReason: j['dispute_reason'] as String?,
        decisionNote: j['decision_note'] as String?,
      );
}

class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amount,
    required this.method,
    required this.reference,
    this.account,
    this.at,
  });

  final int id;
  final double amount;

  /// gcash, maya or bank.
  final String method;
  final String reference;
  final String? account;
  final DateTime? at;

  factory Withdrawal.fromJson(Map<String, dynamic> j) => Withdrawal(
        id: j['id'] as int,
        amount: _d(j['amount']),
        method: j['method'] as String,
        reference: j['reference'] as String,
        account: j['account'] as String?,
        at: _at(j['at']),
      );
}

class PayoutAccount {
  const PayoutAccount({required this.method, required this.account});

  final String method;

  /// Masked, e.g. •••••••6543.
  final String account;

  String get label => switch (method) { 'gcash' => 'GCash', 'maya' => 'Maya', 'bank' => 'Bank', _ => method };

  factory PayoutAccount.fromJson(Map<String, dynamic> j) =>
      PayoutAccount(method: j['method'] as String, account: j['account'] as String);
}

class WalletSummary {
  const WalletSummary({
    required this.available,
    required this.awaitingRelease,
    required this.pendingEarned,
    required this.pendingDeductions,
    required this.disputed,
    required this.weekStart,
    this.closesAt,
    this.payout,
    this.deductions = const [],
    this.withdrawals = const [],
  });

  /// What the rider can withdraw now; negative when deductions were more than
  /// the pay (carried into next week).
  final double available;

  /// Net of closed payslips the station has not released yet.
  final double awaitingRelease;

  /// This week's pay so far, before its cutoff.
  final double pendingEarned;
  final double pendingDeductions;

  /// Deductions the rider disputed, waiting for the station manager.
  final double disputed;
  final DateTime weekStart;

  /// This week's cutoff: Sunday night.
  final DateTime? closesAt;
  final PayoutAccount? payout;

  /// Deductions not on a released payslip yet (newest first).
  final List<WalletDeduction> deductions;

  /// The latest withdrawals, newest first.
  final List<Withdrawal> withdrawals;

  double get thisWeekNet => pendingEarned - pendingDeductions;

  factory WalletSummary.fromJson(Map<String, dynamic> j) => WalletSummary(
        available: _d(j['available']),
        awaitingRelease: _d(j['awaiting_release']),
        pendingEarned: _d(j['pending_earned']),
        pendingDeductions: _d(j['pending_deductions']),
        disputed: _d(j['disputed']),
        weekStart: DateTime.parse(j['week_start'] as String),
        closesAt: _at(j['closes_at']),
        payout: j['payout'] is Map ? PayoutAccount.fromJson(_m(j['payout'])) : null,
        deductions: [for (final d in j['deductions'] as List? ?? const []) WalletDeduction.fromJson(_m(d))],
        withdrawals: [for (final w in j['withdrawals'] as List? ?? const []) Withdrawal.fromJson(_m(w))],
      );
}

/// One task's pay on a payslip.
class PayslipEarning {
  const PayslipEarning({required this.kind, required this.amount, this.at, this.trackingNo, this.parcelClass});

  /// pickup, delivery or return.
  final String kind;
  final double amount;
  final DateTime? at;
  final String? trackingNo;
  final String? parcelClass;

  factory PayslipEarning.fromJson(Map<String, dynamic> j) => PayslipEarning(
        kind: j['kind'] as String,
        amount: _d(j['amount']),
        at: _at(j['at']),
        trackingNo: j['tracking_no'] as String?,
        parcelClass: j['parcel_class'] as String?,
      );
}

/// A week's pay: earnings less deductions.
class Payslip {
  const Payslip({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.pickups,
    required this.deliveries,
    required this.returns,
    required this.earned,
    required this.deductions,
    required this.net,
    required this.status,
    this.releasedAt,
    this.earnings = const [],
    this.deductionItems = const [],
  });

  final int id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int pickups;
  final int deliveries;
  final int returns;
  final double earned;
  final double deductions;
  final double net;

  /// closed (waiting for the station to release it) or released.
  final String status;
  final DateTime? releasedAt;

  /// Only on the payslip detail.
  final List<PayslipEarning> earnings;
  final List<WalletDeduction> deductionItems;

  bool get isReleased => status == 'released';

  factory Payslip.fromJson(Map<String, dynamic> j) => Payslip(
        id: j['id'] as int,
        weekStart: DateTime.parse(j['week_start'] as String),
        weekEnd: DateTime.parse(j['week_end'] as String),
        pickups: j['pickups'] as int,
        deliveries: j['deliveries'] as int,
        returns: j['returns'] as int,
        earned: _d(j['earned']),
        deductions: _d(j['deductions']),
        net: _d(j['net']),
        status: j['status'] as String,
        releasedAt: _at(j['released_at']),
        earnings: [for (final e in j['earnings'] as List? ?? const []) PayslipEarning.fromJson(_m(e))],
        deductionItems: [for (final d in j['deduction_items'] as List? ?? const []) WalletDeduction.fromJson(_m(d))],
      );
}
