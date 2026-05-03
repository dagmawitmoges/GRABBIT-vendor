import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:grabbit_vendor_app/features/auth/provider/auth_provider.dart';
import 'package:grabbit_vendor_app/features/auth/screens/login_screen.dart';
import 'package:grabbit_vendor_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:grabbit_vendor_app/features/deals/screens/deals_screen.dart';
import 'package:grabbit_vendor_app/features/deals/screens/create_deal_screen.dart';
import 'package:grabbit_vendor_app/features/deals/screens/deal_detail_screen.dart';
import 'package:grabbit_vendor_app/features/deals/screens/edit_deal_screen.dart';

import 'package:grabbit_vendor_app/features/orders/screens/orders_screen.dart';
import 'package:grabbit_vendor_app/features/orders/screens/order_detail_screen.dart';
import 'package:grabbit_vendor_app/features/profile/screens/profile_screen.dart';
import 'package:grabbit_vendor_app/features/notifications/screens/notifications_screen.dart';
import 'package:grabbit_vendor_app/router/app_shell.dart';

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/login',

    // 🔥 makes router reactive to auth changes
    refreshListenable: ref.read(authListenerProvider),

    redirect: (context, state) {
      final authState = ref.read(authProvider);

      if (!authState.isInitialized) return null;

      final isLoggedIn = authState.isAuthenticated;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isGoingToLogin ? null : '/login';
      }

      if (isLoggedIn && isGoingToLogin) {
        return '/home';
      }

      return null;
    },

    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
          GoRoute(
            path: '/order/:orderId',
            builder: (context, state) {
              final id = state.pathParameters['orderId']!;
              return OrderDetailScreen(orderId: id);
            },
          ),
          GoRoute(path: '/deals', builder: (_, __) => const DealsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),

          GoRoute(
            path: '/create-deal',
            builder: (_, __) => const CreateDealScreen(),
          ),
          GoRoute(
            path: '/deal/:dealId',
            builder: (context, state) {
              final id = state.pathParameters['dealId']!;
              return DealDetailScreen(dealId: id);
            },
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = state.pathParameters['dealId']!;
                  return EditDealScreen(dealId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
