import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit_vendor_app/core/providers/vendor_notification_count_provider.dart';
import 'package:grabbit_vendor_app/core/theme/theme_mode_provider.dart';
import 'package:grabbit_vendor_app/core/widgets/grabbit_logo.dart';

class VendorShellAppBar extends ConsumerWidget {
  const VendorShellAppBar({super.key});

  static String titleForLocation(String location) {
    if (location.startsWith('/home')) return 'Home';
    if (location.startsWith('/orders')) return 'Orders';
    if (location.startsWith('/deals')) return 'Your deals';
    if (location.startsWith('/profile')) return 'My profile';
    if (location.startsWith('/notifications')) return 'Notifications';
    if (RegExp(r'^/deal/[^/]+$').hasMatch(location)) return 'Deal details';
    if (RegExp(r'^/order/[^/]+$').hasMatch(location)) return 'Order details';
    return 'Grabbit Vendor';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final location = GoRouter.of(context).state.matchedLocation;
    final title = titleForLocation(location);
    final isHome = location.startsWith('/home');
    final themeMode = ref.watch(themeModeProvider);
    final countAsync = ref.watch(vendorNotificationCountProvider);

    final showBack = location.startsWith('/notifications') ||
        RegExp(r'^/deal/[^/]+$').hasMatch(location) ||
        RegExp(r'^/order/[^/]+$').hasMatch(location);

    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 10),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/deals');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: scheme.onSurface,
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isHome
                      ? GrabbitLogo(
                          height: 36,
                          color: scheme.onSurface,
                        )
                      : Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              countAsync.when(
                data: (count) => _NotificationButton(
                  count: count,
                  onPressed: () async {
                    await context.push('/notifications');
                    ref.invalidate(vendorNotificationCountProvider);
                  },
                ),
                loading: () => IconButton(
                  tooltip: 'Notifications',
                  onPressed: () async {
                    await context.push('/notifications');
                    ref.invalidate(vendorNotificationCountProvider);
                  },
                  icon: const Icon(Icons.notifications_outlined),
                  color: scheme.onSurface,
                ),
                error: (e, st) => IconButton(
                  tooltip: 'Notifications',
                  onPressed: () async {
                    await context.push('/notifications');
                    ref.invalidate(vendorNotificationCountProvider);
                  },
                  icon: const Icon(Icons.notifications_outlined),
                  color: scheme.onSurface,
                ),
              ),
              IconButton(
                tooltip: _themeTooltip(themeMode),
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).cycle(),
                icon: Icon(_themeIcon(themeMode)),
                color: scheme.onSurface,
              ),
              IconButton(
                tooltip: 'Profile',
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.account_circle_outlined),
                color: scheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _themeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
  }

  static String _themeTooltip(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Theme: light (tap for dark)',
      ThemeMode.dark => 'Theme: dark (tap for system)',
      ThemeMode.system => 'Theme: system (tap for light)',
    };
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: scheme.primary,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
        ),
      ),
      child: IconButton(
        tooltip: 'Notifications',
        onPressed: onPressed,
        icon: const Icon(Icons.notifications_outlined),
        color: scheme.onSurface,
      ),
    );
  }
}
