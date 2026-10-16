class FormatUtils {
  FormatUtils._();

  /// 1450 -> ₱1,450.00
  static String peso(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '₱$whole.${parts[1]}';
  }
}
