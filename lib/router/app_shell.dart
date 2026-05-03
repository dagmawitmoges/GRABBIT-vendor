import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit_vendor_app/core/theme/vendor_theme.dart';
import 'package:grabbit_vendor_app/router/vendor_shell_app_bar.dart';

/// Extra scroll padding for screens inside [AppShell] when [Scaffold.extendBody]
/// is true — keeps content above the floating bottom nav + system inset.
double appShellBodyBottomPadding(BuildContext context) {
  const floatingNavOuterMargin = 20.0;
  const floatingNavContentHeight = 78.0;
  return floatingNavOuterMargin +
      floatingNavContentHeight +
      MediaQuery.viewPaddingOf(context).bottom;
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabRoutes = <String>['/home', '/orders', '/deals', '/profile'];

  static int? selectedTabIndex(String location) {
    if (location.startsWith('/create-deal') ||
        location.startsWith('/notifications')) {
      return null;
    }
    if (location.startsWith('/deal/')) {
      return 2;
    }
    if (location.startsWith('/order/')) {
      return 1;
    }
    final index = _tabRoutes.indexWhere((route) => location.startsWith(route));
    if (index < 0) return null;
    return index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouter.of(context).state.matchedLocation;
    final currentIndex = selectedTabIndex(location);
    final showTopBar = !location.startsWith('/create-deal') &&
        !RegExp(r'^/deal/[^/]+/edit$').hasMatch(location);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTopBar) const VendorShellAppBar(),
          Expanded(child: child),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: VendorTheme.cardShadowFor(context),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: currentIndex == 0,
                    onTap: () => context.go('/home'),
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Orders',
                    selected: currentIndex == 1,
                    onTap: () => context.go('/orders'),
                  ),
                  _NavItem(
                    icon: Icons.local_offer_rounded,
                    label: 'Deals',
                    selected: currentIndex == 2,
                    onTap: () => context.go('/deals'),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: currentIndex == 3,
                    onTap: () => context.go('/profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? scheme.primary : muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.primary : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
