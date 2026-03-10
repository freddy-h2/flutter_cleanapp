import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/app.dart';
import 'package:flutter_cleanapp/core/background_service.dart';
import 'package:flutter_cleanapp/core/notification_service.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:timezone/data/latest_all.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();
  await BackgroundService.instance.initialize();
  tz.initializeTimeZones();
  runApp(const LimpyApp());
}
