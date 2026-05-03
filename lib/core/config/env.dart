import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// `--dart-define=BASE_URL=...` wins, then `.env` / `.env.example`, then default.
  static String get baseUrl {
    const fromBase = String.fromEnvironment('BASE_URL');
    const fromApi = String.fromEnvironment('API_BASE_URL');
    if (fromBase.isNotEmpty) return fromBase;
    if (fromApi.isNotEmpty) return fromApi;
    final fromFile = _dotenv('BASE_URL');
    if (fromFile.isNotEmpty) return fromFile;
    return 'http://localhost:3000';
  }

  static String get supabaseUrl {
    const d = String.fromEnvironment('SUPABASE_URL');
    if (d.isNotEmpty) return d;
    return _dotenv('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    const d = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (d.isNotEmpty) return d;
    return _dotenv('SUPABASE_ANON_KEY');
  }

  /// True when URL/key are still template values from `.env.example` (common mistake).
  static bool get supabaseEnvIsPlaceholder {
    final u = supabaseUrl.trim().toLowerCase();
    final k = supabaseAnonKey.trim();
    if (u.isEmpty || k.isEmpty) return false;
    final badUrl = u.contains('your_project_ref');
    final badKey = k.toUpperCase() == 'YOUR_SUPABASE_ANON_KEY' ||
        k.toLowerCase() == 'your_supabase_anon_key';
    return badUrl || badKey;
  }

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseEnvIsPlaceholder;

  /// Storage bucket for deal photos (create in Supabase → Storage; allow public read if using getPublicUrl).
  static String get supabaseDealImagesBucket {
    const fromDef = String.fromEnvironment('SUPABASE_DEAL_IMAGES_BUCKET');
    if (fromDef.isNotEmpty) return fromDef;
    final f = _dotenv('SUPABASE_DEAL_IMAGES_BUCKET');
    if (f.isNotEmpty) return f;
    return 'deal-images';
  }

  static bool get isDevelopment => true;

  static String _dotenv(String key) {
    if (!dotenv.isInitialized) return '';
    return dotenv.maybeGet(key)?.trim() ?? '';
  }
}
