class BackendConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const authRedirect = 'workcheck://auth/callback';
  static bool get isConfigured =>
      Uri.tryParse(url)?.scheme == 'https' &&
      publishableKey.startsWith('sb_publishable_');
}
