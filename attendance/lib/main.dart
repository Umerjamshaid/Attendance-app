import 'package:attendance/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/backend_config.dart';
import 'services/preview_company_backend.dart';
import 'services/supabase_company_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  if (!BackendConfig.isConfigured) {
    runAttendanceApp(backend: PreviewCompanyBackend(available: false));
    return;
  }
  try {
    final preferences = await SharedPreferences.getInstance();
    await Supabase.initialize(
      url: BackendConfig.url,
      publishableKey: BackendConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUriPredicate: BackendConfig.isAuthCallback,
      ),
    );
    runAttendanceApp(
      backend: SupabaseCompanyBackend(
        Supabase.instance.client,
        preferences: preferences,
      ),
    );
  } catch (_) {
    runAttendanceApp(backend: PreviewCompanyBackend(available: false));
  }
}
