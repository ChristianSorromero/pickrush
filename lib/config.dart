class AppConfig {
  AppConfig._();

  /// Picksell's API (the rider API lives at /api/rider/...).
  ///
  /// Picksell runs on this computer (`php artisan serve`, port 8000) and the
  /// Cloudflare tunnel publishes it as https://pick-sell.shop, so a physical
  /// device reaches it from any network.
  ///
  /// Override for other setups, e.g. the Android emulator without the tunnel:
  ///   flutter run --dart-define=BASE_URL=http://10.0.2.2:8000
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://pick-sell.shop',
  );
}
