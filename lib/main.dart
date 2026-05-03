import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit_vendor_app/core/config/env.dart';
import 'package:grabbit_vendor_app/core/config/load_app_env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:grabbit_vendor_app/core/theme/theme_mode_provider.dart';
import 'package:grabbit_vendor_app/core/theme/vendor_theme.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAppEnv();

  if (Env.supabaseEnvIsPlaceholder) {
    debugPrint(
      'Supabase URL/key are still placeholders. Edit `.env.example` (used on web) '
      'or create `.env` in the project root (overrides on mobile/desktop) with your '
      'real Project URL and anon key from Supabase → Project Settings → API. '
      'Then run `flutter run` again (hot restart is not enough for asset/env changes).',
    );
  }

  if (kIsWeb && Env.isDevelopment && !Env.hasSupabase) {
    debugPrint(
      'Auth: using REST login at ${Env.baseUrl} (not Supabase). '
      'Set SUPABASE_URL and SUPABASE_ANON_KEY in .env.example (web) or .env '
      '(mobile/desktop). On web, REST on localhost also needs CORS on your API.',
    );
  }

  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = createRouter(ref);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Grabbit Vendor',
      theme: VendorTheme.light(),
      darkTheme: VendorTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}