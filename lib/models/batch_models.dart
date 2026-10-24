/// Batches as Picksell's rider API returns them (`/api/rider/batches`).
///
/// A batch is the tasks the station gave this rider in one go:
/// - pickup: a stop is one seller; collect, then bring everything to the station.
/// - delivery: a stop is one recipient (a buyer, or the seller for a return);
///   load at the station, deliver, then return with the cash and any parcel
///   not delivered.
library;

enum BatchType {
  pickup,
  delivery;

  static BatchType parse(String? v) => v == 'delivery' ? BatchType.delivery : BatchType.pickup;
}

enum BatchStatus {
  offered,
  accepted,
  declined,
  completed,
  cancelled;

  static BatchStatus parse(String? v) => switch (v) {
        'accepted' => BatchStatus.accepted,
        'declined' => BatchStatus.declined,
        'completed' => BatchStatus.completed,
        'cancelled' => BatchStatus.cancelled,
        _ => BatchStatus.offered,
      };
}

/// Progress bar. Pickup: assigned → pickup → dropped off.
/// Delivery: assigned → pickup (loading at the station) → deliver → done.
enum BatchStage {
  assigned,
  pickup,
  deliver,
  droppedOff;

  static BatchStage parse(String? v) => switch (v) {
        'pickup' => BatchStage.pickup,
        'deliver' => BatchStage.deliver,
        'dropped_off' => BatchStage.droppedOff,
        _ => BatchStage.assigned,
      };
}

/// One parcel's state.
/// Pickup: to scan at the seller, collected, received by the station, or not
/// collected (back in the station's queue).
/// Delivery: to load, loaded, out for delivery, delivered, failed (still with
/// the rider), or returned (handed back at the station).
enum ItemStatus {
  toPick,
  pickedUp,
  received,
  notCollected,
  toLoad,
  loaded,
  outForDelivery,
  delivered,
  failed,
  returned;

  static ItemStatus parse(String? v) => switch (v) {
        'picked_up' => ItemStatus.pickedUp,
        'received' => ItemStatus.received,
        'not_collected' => ItemStatus.notCollected,
        'to_load' => ItemStatus.toLoad,
        'loaded' => ItemStatus.loaded,
        'out_for_delivery' => ItemStatus.outForDelivery,
        'delivered' => ItemStatus.delivered,
        'failed' => ItemStatus.failed,
        'returned' => ItemStatus.returned,
        _ => ItemStatus.toPick,
      };
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

double? _double(Object? v) => (v as num?)?.toDouble();

/// A map pin. Null coordinates mean nobody has pinned the place yet.
class Pin {
  const Pin(this.lat, this.lng);
  final double lat;
  final double lng;

  static Pin? from(Map<String, dynamic> j) {
    final lat = _double(j['lat']);
    final lng = _double(j['lng']);
    return lat == null || lng == null ? null : Pin(lat, lng);
  }
}

class BatchItem {
  const BatchItem({
    required this.assignmentId,
    required this.trackingNo,
    required this.status,
    this.kind = 'pickup',
    this.orderNumber,
    this.description,
    this.weightKg,
    this.size,
    this.codAmount = 0,
    this.note,
    this.doneAt,
  });

  final int assignmentId;

  /// pickup, delivery, or return (back to the seller).
  final String kind;
  final String trackingNo;
  final String? orderNumber;
  final String? description;
  final double? weightKg;
  final String? size;

  /// Cash to collect at the door (0 for returns and prepaid).
  final double codAmount;
  final ItemStatus status;

  /// Why it was not collected / not delivered.
  final String? note;
  final DateTime? doneAt;

  bool get isToPick => status == ItemStatus.toPick;
  bool get isPickedUp =>
      status == ItemStatus.pickedUp || status == ItemStatus.received;
  bool get isLoaded => status != ItemStatus.toLoad;
  bool get isToDeliver => status == ItemStatus.outForDelivery;
  bool get isReturn => kind == 'return';

  /// The label for the stop list: the marketplace order, else the waybill.
  String get reference => orderNumber != null ? '#$orderNumber' : trackingNo;

  factory BatchItem.fromJson(Map<String, dynamic> j) => BatchItem(
        assignmentId: j['assignment_id'] as int,
        kind: (j['kind'] as String?) ?? 'pickup',
        trackingNo: j['tracking_no'] as String,
        orderNumber: j['order_number'] as String?,
        description: j['description'] as String?,
        weightKg: _double(j['weight_kg']),
        size: j['size'] as String?,
        codAmount: _double(j['cod_amount']) ?? 0,
        status: ItemStatus.parse(j['status'] as String?),
        note: j['note'] as String?,
        doneAt: _date(j['done_at']),
      );
}

class BatchStop {
  const BatchStop({
    required this.number,
    required this.name,
    required this.status,
    required this.parcelCount,
    required this.items,
    this.kind = 'pickup',
    this.pickedCount = 0,
    this.notCollectedCount = 0,
    this.mobile,
    this.address,
    this.pin,
    this.arrivedAt,
    this.codTotal = 0,
    this.earnings = 0,
  });

  final int number;

  /// pickup, delivery, or return (to the seller).
  final String kind;

  /// The seller (pickup, return) or the buyer (delivery).
  final String name;
  final String? mobile;
  final String? address;
  final Pin? pin;

  /// When the rider slid "Arrived" here (null: not yet).
  final DateTime? arrivedAt;

  /// pending, or done: picked_up (pickup); delivered, failed or partial (delivery).
  final String status;
  final int parcelCount;
  final int pickedCount;
  final int notCollectedCount;
  final double codTotal;
  final double earnings;
  final List<BatchItem> items;

  bool get isDone => status != 'pending';

  /// Pickup screens call a finished stop "picked up".
  bool get isPickedUp => isDone;
  bool get isReturn => kind == 'return';
  String get sellerName => name;
  String? get sellerMobile => mobile;

  List<BatchItem> get toPick => items.where((i) => i.isToPick).toList();
  List<BatchItem> get toDeliver => items.where((i) => i.isToDeliver).toList();

  /// Parcels still to handle here, whatever the batch type.
  List<BatchItem> get open => kind == 'pickup' ? toPick : toDeliver;
  bool get hasArrived => arrivedAt != null;

  factory BatchStop.fromJson(Map<String, dynamic> j) => BatchStop(
        number: j['number'] as int,
        kind: (j['kind'] as String?) ?? 'pickup',
        name: (j['name'] ?? j['seller_name']) as String,
        mobile: (j['mobile'] ?? j['seller_mobile']) as String?,
        address: j['address'] as String?,
        pin: Pin.from(j),
        arrivedAt: _date(j['arrived_at']),
        status: (j['status'] as String?) ?? 'pending',
        parcelCount: j['parcel_count'] as int,
        pickedCount: (j['picked_count'] as int?) ?? 0,
        notCollectedCount: (j['not_collected_count'] as int?) ?? 0,
        codTotal: _double(j['cod_total']) ?? 0,
        earnings: _double(j['earnings']) ?? 0,
        items: [
          for (final i in j['items'] as List)
            BatchItem.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
      );
}

class HubContact {
  const HubContact({required this.name, this.mobile});
  final String name;
  final String? mobile;
}

class DropOff {
  const DropOff({
    required this.name,
    this.address,
    this.pin,
    this.arrivedAt,
    this.manager,
  });

  final String name;
  final String? address;
  final Pin? pin;
  final DateTime? arrivedAt;
  final HubContact? manager;

  /// What Google Maps searches for when there is no pin.
  String get searchText => [name, address].whereType<String>().join(', ');

  factory DropOff.fromJson(Map<String, dynamic> j) {
    final m = j['manager'] is Map ? Map<String, dynamic>.from(j['manager'] as Map) : null;
    return DropOff(
      name: j['name'] as String,
      address: j['address'] as String?,
      pin: Pin.from(j),
      arrivedAt: _date(j['arrived_at']),
      manager: m == null
          ? null
          : HubContact(name: m['name'] as String, mobile: m['mobile'] as String?),
    );
  }
}

class RiderBatch {
  const RiderBatch({
    required this.id,
    required this.batchNo,
    required this.status,
    required this.stage,
    required this.parcelCount,
    required this.estEarnings,
    required this.stops,
    this.type = BatchType.pickup,
    this.pickedCount = 0,
    this.droppedOffCount = 0,
    this.notCollectedCount = 0,
    this.loadedCount = 0,
    this.deliveredCount = 0,
    this.failedCount = 0,
    this.toReturnCount = 0,
    this.codTotal = 0,
    this.codCollected = 0,
    this.toRemit = 0,
    this.remitted = false,
    this.arrivalRadiusM = 150,
    this.arrivalLocked = false,
    this.offeredAt,
    this.startedAt,
    this.lastPickupAt,
    this.lastDeliveryAt,
    this.dropOff,
  });

  final int id;
  final BatchType type;
  final String batchNo;
  final BatchStatus status;
  final BatchStage stage;
  final DateTime? offeredAt;
  final int parcelCount;
  final double estEarnings;
  final int arrivalRadiusM;

  /// The server refuses "Arrived" farther than [arrivalRadiusM] from a pin.
  final bool arrivalLocked;
  final DropOff? dropOff;
  final List<BatchStop> stops;

  // Pickup
  final int pickedCount;
  final int droppedOffCount;
  final int notCollectedCount;
  final DateTime? lastPickupAt;

  // Delivery
  final DateTime? startedAt;
  final int loadedCount;
  final int deliveredCount;
  final int failedCount;
  final int toReturnCount;
  final double codTotal;
  final double codCollected;
  final double toRemit;
  final bool remitted;
  final DateTime? lastDeliveryAt;

  bool get isDelivery => type == BatchType.delivery;
  bool get isOffer => status == BatchStatus.offered;
  bool get allPickedUp => stops.every((s) => s.isDone);

  /// Every stop handled (pickup: collected; delivery: delivered or failed).
  bool get allStopsDone => allPickedUp;
  bool get hasStarted => startedAt != null;

  /// Collected and still with the rider (not yet scanned in at the station).
  int get carrying => pickedCount - droppedOffCount;

  /// The first stop not done yet: where the rider should go now.
  BatchStop? get nextStop {
    for (final s in stops) {
      if (!s.isDone) return s;
    }
    return null;
  }

  /// Every parcel collected, for the pickup handover checklist.
  List<BatchItem> get collected =>
      [for (final s in stops) ...s.items.where((i) => i.isPickedUp)];

  /// Every parcel of the batch, in stop order.
  List<BatchItem> get items => [for (final s in stops) ...s.items];

  /// Parcels not delivered: handed back at the station, or still to hand back.
  List<BatchItem> get returns => items
      .where((i) => i.status == ItemStatus.failed || i.status == ItemStatus.returned)
      .toList();

  factory RiderBatch.fromJson(Map<String, dynamic> j) => RiderBatch(
        id: j['id'] as int,
        type: BatchType.parse(j['type'] as String?),
        batchNo: j['batch_no'] as String,
        status: BatchStatus.parse(j['status'] as String?),
        stage: BatchStage.parse(j['stage'] as String?),
        offeredAt: _date(j['offered_at']),
        lastPickupAt: _date(j['last_pickup_at']),
        lastDeliveryAt: _date(j['last_delivery_at']),
        startedAt: _date(j['started_at']),
        parcelCount: j['parcel_count'] as int,
        pickedCount: (j['picked_count'] as int?) ?? 0,
        droppedOffCount: (j['dropped_off_count'] as int?) ?? 0,
        notCollectedCount: (j['not_collected_count'] as int?) ?? 0,
        loadedCount: (j['loaded_count'] as int?) ?? 0,
        deliveredCount: (j['delivered_count'] as int?) ?? 0,
        failedCount: (j['failed_count'] as int?) ?? 0,
        toReturnCount: (j['to_return_count'] as int?) ?? 0,
        codTotal: _double(j['cod_total']) ?? 0,
        codCollected: _double(j['cod_collected']) ?? 0,
        toRemit: _double(j['to_remit']) ?? 0,
        remitted: (j['remitted'] as bool?) ?? false,
        estEarnings: (j['est_earnings'] as num).toDouble(),
        arrivalRadiusM: (j['arrival_radius_m'] as int?) ?? 150,
        arrivalLocked: (j['arrival_locked'] as bool?) ?? false,
        dropOff: j['drop_off'] is Map
            ? DropOff.fromJson(Map<String, dynamic>.from(j['drop_off'] as Map))
            : null,
        stops: [
          for (final s in j['stops'] as List)
            BatchStop.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}

/// An entry of a closed list from `/api/rider/options`.
class Choice {
  const Choice(this.key, this.label);
  final String key;
  final String label;
}

class RiderOptions {
  const RiderOptions({
    required this.pickupFailureReasons,
    required this.riderProblems,
    this.deliveryFailureReasons = const [],
  });

  final List<Choice> pickupFailureReasons;
  final List<Choice> riderProblems;
  final List<Choice> deliveryFailureReasons;

  factory RiderOptions.fromJson(Map<String, dynamic> j) {
    List<Choice> list(Object? v) => [
          for (final c in (v as List? ?? const []))
            Choice((c as Map)['key'] as String, c['label'] as String),
        ];
    return RiderOptions(
      pickupFailureReasons: list(j['pickup_failure_reasons']),
      riderProblems: list(j['rider_problems']),
      deliveryFailureReasons: list(j['delivery_failure_reasons']),
    );
  }
}
