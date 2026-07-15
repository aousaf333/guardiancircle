import 'package:flutter/material.dart';
import 'package:guardiancircle/services/supabase_service.dart';

Future<void> initializeSupabase() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.init();
}
