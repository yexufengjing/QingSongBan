import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import 'excel_service.dart';

final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService(ref.watch(appDatabaseProvider));
});
