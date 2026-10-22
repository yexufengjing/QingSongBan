import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/assistant/assistant_page_test.dart' as suite0;
import '../test/assistant/assistant_settings_page_test.dart' as suite2;
import '../test/assistant/assistant_result_content_test.dart' as suite5;
import '../test/assistant/assistant_quick_queries_page_test.dart' as suite6;
import '../test/assistant/assistant_quick_query_test.dart' as suite7;
import '../test/assistant/assistant_favorites_test.dart' as suite8;
import '../test/assistant/assistant_business_reader_test.dart' as suite9;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('assistant_page_test', suite0.main);
  group('assistant_settings_page_test', suite2.main);
  group('assistant_result_content_test', suite5.main);
  group('assistant_quick_queries_page_test', suite6.main);
  group('assistant_quick_query_test', suite7.main);
  group('assistant_favorites_test', suite8.main);
  group('assistant_business_reader_test', suite9.main);
}
