import 'package:integration_test/integration_test.dart';

import '../test/assistant/assistant_source_navigation_test.dart' as suite;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  suite.main();
}
