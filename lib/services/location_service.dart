import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:rider_app/models/batch_models.dart';

/// A GPS reading sent with "Arrived" so the server can check it against the pin.
class GpsFix {
  const GpsFix(this.lat, this.lng, this.accuracy);
  final double lat;
  final double lng;
  final double accuracy;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'accuracy': accuracy};

  factory GpsFix.of(Position p) => GpsFix(p.latitude, p.longitude, p.accuracy);
}

class LocationProblem implements Exception {
  LocationProblem(this.message, {this.openSettings = false});
  final String message;

  /// Permission was denied for good: only the phone's settings can fix it.
  final bool openSettings;

  @override
  String toString() => message;
}

/// The phone's GPS, free (no maps service involved). Distances are straight
/// lines; the ETA is a rough motorcycle estimate for city roads.
class LocationService {
  /// Average city speed for a rider, and how much longer roads are than a straight line.
  static const _kmh = 22.0;
  static const _roadFactor = 1.35;

  Future<void> _ensureAllowed() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationProblem('Turn on Location (GPS) to continue.', openSettings: true);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationProblem('Allow location so we can confirm you arrived.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationProblem('Location is blocked for Pickrush. Allow it in Settings.',
          openSettings: true);
    }
  }

  /// One accurate reading (for "Arrived").
  Future<GpsFix> current() async {
    await _ensureAllowed();
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return GpsFix.of(p);
  }

  /// Live readings while a trip screen is open.
  Stream<GpsFix> watch() async* {
    await _ensureAllowed();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map(GpsFix.of);
  }

  Future<void> openSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  static double metres(GpsFix from, Pin to) =>
      Geolocator.distanceBetween(from.lat, from.lng, to.lat, to.lng);

  static Duration eta(double metres) => Duration(
      minutes: (metres * _roadFactor / (_kmh * 1000 / 60)).ceil().clamp(1, 600));

  /// "120 m" or "1.4 km".
  static String distanceLabel(double metres) => metres < 1000
      ? '${metres.round()} m'
      : '${(metres / 1000).toStringAsFixed(1)} km';

  static String etaLabel(double metres) {
    final m = eta(metres).inMinutes;
    return m < 60 ? '$m min${m == 1 ? '' : 's'}' : '${m ~/ 60} h ${m % 60} min';
  }
}

final LocationService locationService = LocationService();
