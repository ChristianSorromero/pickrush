import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rider_app/models/dashboard_models.dart';
import 'package:rider_app/services/rider_task_service.dart';

/// Polls Picksell while the app is open so the rider hears about a new
/// pickup batch within seconds of the station assigning it.
///
/// Screens listen to it: [changes] goes up whenever something the station sent
/// changed (reload your data), and [onNewOffer] fires once per new batch.
///
/// Background push (app closed) needs Firebase Cloud Messaging; until then the
/// rider sees offers as soon as they open the app.
///
/// Every poll is also the app's check-in: the server keeps an online rider
/// online only while check-ins keep coming. In the background it slows to
/// [backgroundInterval]; once the phone closes or freezes the app they stop,
/// and after a few minutes the server sets the rider offline.
class AssignmentWatcher extends ChangeNotifier {
  AssignmentWatcher({
    this.interval = const Duration(seconds: 20),
    this.backgroundInterval = const Duration(seconds: 60),
  });

  final Duration interval;
  final Duration backgroundInterval;

  Timer? _timer;
  bool _inBackground = false;
  bool _polling = false;
  final Set<int> _announced = {};
  int? _latestNotificationId;

  int unreadNotifications = 0;
  List<int> offeredBatchIds = const [];
  List<int> offeredDeliveryIds = const [];

  bool get hasPickupOffer => offeredBatchIds.any((id) => !offeredDeliveryIds.contains(id));
  bool get hasDeliveryOffer => offeredDeliveryIds.isNotEmpty;

  /// Bumped on every change; screens reload when it moves.
  int changes = 0;

  /// A batch the rider has not been told about yet (this session).
  void Function(int batchId, RiderNotification? notification)? onNewOffer;

  /// The token stopped working or the account is no longer active.
  VoidCallback? onSignedOut;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null && !_inBackground) return;
    _timer?.cancel();
    _inBackground = false;
    _timer = Timer.periodic(interval, (_) => poll());
    poll();
  }

  /// The app left the screen: keep checking in, but slowly.
  void background() {
    if (_timer == null || _inBackground) return;
    _timer!.cancel();
    _inBackground = true;
    _timer = Timer.periodic(backgroundInterval, (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _inBackground = false;
  }

  /// Check now (also called after the rider acts, e.g. accepts a batch).
  Future<void> poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final pulse = await riderTasks.pulse();
      final changed = pulse.unreadNotifications != unreadNotifications ||
          pulse.latest?.id != _latestNotificationId ||
          !listEquals(pulse.offeredBatchIds, offeredBatchIds);

      unreadNotifications = pulse.unreadNotifications;
      offeredBatchIds = pulse.offeredBatchIds;
      offeredDeliveryIds = pulse.offeredDeliveryIds;
      _latestNotificationId = pulse.latest?.id;

      for (final id in pulse.offeredBatchIds) {
        if (_announced.add(id)) {
          final n = pulse.latest?.batchId == id ? pulse.latest : null;
          onNewOffer?.call(id, n);
        }
      }
      if (changed) {
        changes++;
        notifyListeners();
      }
    } on TaskException catch (e) {
      if (e.signedOut) {
        stop();
        onSignedOut?.call();
      }
      // Offline: try again on the next tick.
    } finally {
      _polling = false;
    }
  }

  /// Something changed on this phone (e.g. went online from Account): screens reload.
  void touch() {
    changes++;
    notifyListeners();
  }

  /// The rider opened the notification list; the badge clears right away.
  void markAllRead() {
    if (unreadNotifications == 0) return;
    unreadNotifications = 0;
    notifyListeners();
  }

  void reset() {
    stop();
    _announced.clear();
    _latestNotificationId = null;
    unreadNotifications = 0;
    offeredBatchIds = const [];
    offeredDeliveryIds = const [];
  }
}

final AssignmentWatcher assignmentWatcher = AssignmentWatcher();
