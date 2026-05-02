import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/provider/auth_provider.dart';
import 'router/app_router.dart';

class GrabbitVendorApp extends ConsumerWidget {
  const GrabbitVendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // ⏳ Show loader until auth is initialized
    if (!authState.isInitialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final router = createRouter(ref);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Grabbit Vendor',

      // 🎨 Basic theme (you can upgrade later)
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0B172D),
      ),

      routerConfig: router,
    );
  }
}
