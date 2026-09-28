const _digits = ['零', '壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖'];
const _places = ['仟', '佰', '拾', ''];
const _sections = ['', '万', '亿', '兆'];

String rmbUppercase(int amountCents) {
  if (amountCents < 0) throw ArgumentError.value(amountCents, 'amountCents');
  final yuan = amountCents ~/ 100;
  final jiao = amountCents ~/ 10 % 10;
  final fen = amountCents % 10;
  final result = StringBuffer('${_integerToChinese(yuan)}元');
  if (jiao > 0) {
    result.write('${_digits[jiao]}角');
  } else if (fen > 0) {
    result.write('零角');
  }
  if (fen > 0) {
    result.write('${_digits[fen]}分');
  } else if (jiao == 0) {
    result.write('整');
  }
  return result.toString();
}

String _integerToChinese(int value) {
  if (value == 0) return _digits[0];
  final chunks = <int>[];
  var remaining = value;
  while (remaining > 0) {
    chunks.add(remaining % 10000);
    remaining ~/= 10000;
  }
  if (chunks.length > _sections.length) {
    throw RangeError.range(value, 0, 9999999999999999, 'value');
  }

  final result = StringBuffer();
  var pendingZero = false;
  for (var index = chunks.length - 1; index >= 0; index--) {
    final chunk = chunks[index];
    if (chunk == 0) {
      pendingZero = result.isNotEmpty;
      continue;
    }
    if (result.isNotEmpty && (pendingZero || chunk < 1000)) {
      result.write(_digits[0]);
    }
    result
      ..write(_fourDigitChunk(chunk))
      ..write(_sections[index]);
    pendingZero = false;
  }
  return result.toString();
}

String _fourDigitChunk(int value) {
  final result = StringBuffer();
  var pendingZero = false;
  for (var position = 0; position < 4; position++) {
    final divisor = switch (position) {
      0 => 1000,
      1 => 100,
      2 => 10,
      _ => 1,
    };
    final digit = value ~/ divisor % 10;
    if (digit == 0) {
      pendingZero = result.isNotEmpty;
      continue;
    }
    if (pendingZero) result.write(_digits[0]);
    result
      ..write(_digits[digit])
      ..write(_places[position]);
    pendingZero = false;
  }
  return result.toString();
}
