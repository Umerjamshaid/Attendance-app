import 'package:attendance/bootstrap.dart';
import 'package:flutter/material.dart';
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
    await Supabase.initialize(
      url: BackendConfig.url,
      publishableKey: BackendConfig.publishableKey,
    );
    runAttendanceApp(backend: SupabaseCompanyBackend(Supabase.instance.client));
  } catch (_) {
    runAttendanceApp(backend: PreviewCompanyBackend(available: false));
  }
}
