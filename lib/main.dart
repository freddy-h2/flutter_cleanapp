import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/app.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const CleanApp());
}
