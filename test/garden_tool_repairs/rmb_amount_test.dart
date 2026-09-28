import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/garden_tool_repairs/domain/rmb_amount.dart';

void main() {
  test('converts zero, integer yuan, jiao and fen', () {
    expect(rmbUppercase(0), '零元整');
    expect(rmbUppercase(438600), '肆仟叁佰捌拾陆元整');
    expect(rmbUppercase(1234), '壹拾贰元叁角肆分');
    expect(rmbUppercase(1001), '壹拾元零角壹分');
    expect(rmbUppercase(5), '零元零角伍分');
  });

  test('converts zeros within and between large-number sections', () {
    expect(rmbUppercase(100000001), '壹佰万元零角壹分');
    expect(rmbUppercase(100000000), '壹佰万元整');
  });
}
