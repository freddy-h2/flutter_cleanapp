import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/app.dart';
import 'package:flutter_cleanapp/core/notification_service.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();
  runApp(const CleanApp());
}
