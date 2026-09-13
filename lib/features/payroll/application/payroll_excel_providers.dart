import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import 'payroll_excel_service.dart';

final payrollExcelServiceProvider = Provider<PayrollExcelService>((ref) {
  return PayrollExcelService(ref.watch(appDatabaseProvider));
});
