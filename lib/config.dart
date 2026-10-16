class AppConfig {
  AppConfig._();

  /// Android emulator → 10.0.2.2 reaches your computer's localhost.
  /// iOS simulator  → use http://127.0.0.1:8000
  /// Physical device / production → set BASE_URL via --dart-define or change the default.
  ///
  /// Example:
  ///   flutter run --dart-define=BASE_URL=https://your-ngrok-url.ngrok-free.app
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://scurvy-scary-bonding.ngrok-free.dev',
  );
}
