import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/demo_data_seeder.dart';
import 'core/database/vehicle_demo_data_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('QSB_SEED_DATA')) {
    final database = AppDatabase();
    try {
      await DemoDataSeeder.seed(database);
    } finally {
      await database.close();
    }
  }
  if (const bool.fromEnvironment('QSB_SEED_VEHICLE_DATA')) {
    final database = AppDatabase();
    try {
      await VehicleDemoDataSeeder.seed(database);
    } finally {
      await database.close();
    }
  }
  runApp(const ProviderScope(child: QingSongBanApp()));
}
