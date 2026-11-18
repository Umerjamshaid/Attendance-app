import 'package:attendance/bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/backend_config.dart';
import 'services/preview_company_backend.dart';
import 'services/supabase_company_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;

Future<void> main() => AttendanceBootstrap.run(() async {
  tzdata.initializeTimeZones();
  if (!BackendConfig.isConfigured) {
    return PreviewCompanyBackend(available: false);
  }
  final preferences = await SharedPreferences.getInstance();
  await Supabase.initialize(
    url: BackendConfig.url,
    publishableKey: BackendConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUriPredicate: BackendConfig.isAuthCallback,
    ),
  );
  return SupabaseCompanyBackend(
    Supabase.instance.client,
    preferences: preferences,
  );
});
