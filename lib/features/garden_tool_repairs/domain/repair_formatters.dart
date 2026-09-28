String formatRepairMoney(int cents, {bool symbol = true}) {
  final value = cents.abs();
  final yuan = value ~/ 100;
  final digits = yuan.toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  final sign = cents < 0 ? '-' : '';
  final prefix = symbol ? '¥' : '';
  return '$sign$prefix$grouped.${(value % 100).toString().padLeft(2, '0')}';
}

String formatRepairQuantity(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}
