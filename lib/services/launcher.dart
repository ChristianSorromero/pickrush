import 'package:rider_app/models/batch_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands off to free apps already on the phone: Google Maps for turn-by-turn,
/// the dialer and SMS for the seller or the station.
class Launcher {
  Launcher._();

  /// Turn-by-turn to a pin when there is one, otherwise to the typed address.
  static Future<bool> navigate({Pin? pin, required String fallback}) => _open(Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'destination': pin == null ? fallback : '${pin.lat},${pin.lng}',
          'travelmode': 'driving',
        },
      ));

  /// Turn-by-turn to one address.
  static Future<bool> navigateTo(String address) => navigate(fallback: address);

  /// The whole batch: every stop in order, ending at the station.
  static Future<bool> route(List<String> stops, String destination) =>
      _open(Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': destination,
        if (stops.isNotEmpty) 'waypoints': stops.join('|'),
        'travelmode': 'driving',
      }));

  static Future<bool> call(String number) =>
      _open(Uri(scheme: 'tel', path: number));

  static Future<bool> sms(String number, {String? body}) => _open(Uri(
        scheme: 'sms',
        path: number,
        queryParameters: body == null ? null : {'body': body},
      ));

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
