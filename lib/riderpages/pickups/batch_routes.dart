import 'package:flutter/material.dart';

import 'package:rider_app/models/batch_models.dart';
import 'package:rider_app/riderpages/deliveries/delivery_batch_screen.dart';
import 'package:rider_app/riderpages/pickups/current_batch_screen.dart';
import 'package:rider_app/riderpages/pickups/new_assignment_screen.dart';

/// Where an accepted batch is worked on: stop by stop for pickups; loading,
/// then the route, for deliveries.
Widget acceptedBatchScreen(RiderBatch batch) => batch.isDelivery
    ? DeliveryBatchScreen(batch: batch)
    : CurrentBatchScreen(batch: batch);

/// Opens a batch where it belongs: an offer on the review screen, an accepted
/// batch on its working screen.
Future<void> openBatch(BuildContext context, RiderBatch batch) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => batch.isOffer
        ? NewAssignmentScreen(batchId: batch.id, initial: batch)
        : acceptedBatchScreen(batch),
  ));
}

/// Opens a batch known only by id (e.g. from a notification).
Future<void> openBatchById(BuildContext context, int batchId) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => NewAssignmentScreen(batchId: batchId),
  ));
}
