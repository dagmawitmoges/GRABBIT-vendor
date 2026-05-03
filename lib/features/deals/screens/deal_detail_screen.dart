import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit_vendor_app/core/data/vendor_repository.dart';
import 'package:grabbit_vendor_app/core/theme/vendor_theme.dart';
import 'package:grabbit_vendor_app/router/app_shell.dart';
import 'package:intl/intl.dart';

class DealDetailScreen extends StatefulWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return VendorRepository().getDealById(widget.dealId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  String _status(Map<String, dynamic> deal) {
    final isActive = deal['is_active'] == true;
    final expiry = DateTime.tryParse(deal['expiry_date']?.toString() ?? '');

    if (!isActive) return 'Inactive';
    if (expiry != null && expiry.isBefore(DateTime.now())) return 'Expired';

    final qty = deal['quantity_available'] ?? 0;
    if (qty == 0) return 'Sold out';

    return 'Active';
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'Active':
        return scheme.primary;
      case 'Sold out':
        return const Color(0xFFE67E22);
      case 'Expired':
        return scheme.error;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  String? _imageUrl(Map<String, dynamic> deal) {
    final raw = deal['images'];
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is String && first.isNotEmpty) return first;
    }
    return null;
  }

  Future<void> _confirmSoldOut() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as sold out?'),
        content: const Text(
          'Customers will see this deal as sold out. You can edit quantity later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark sold out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await VendorRepository().markDealSoldOut(widget.dealId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal marked as sold out')),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _toggleActive(bool currentlyActive) async {
    final action = currentlyActive ? 'deactivate' : 'activate';
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(currentlyActive ? 'Deactivate deal?' : 'Activate deal?'),
        content: Text(
          currentlyActive
              ? 'This deal will be hidden from customers until you activate it again.'
              : 'This deal will be visible to customers again (if not expired and in stock).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(currentlyActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await VendorRepository().updateDeal(
        dealId: widget.dealId,
        isActive: !currentlyActive,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deal ${action}d')),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = appShellBodyBottomPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final deal = snapshot.data!;
          final status = _status(deal);
          final statusColor = _statusColor(status, scheme);
          final imgUrl = _imageUrl(deal);
          final qty = deal['quantity_available'] ?? 0;
          final isActive = deal['is_active'] == true;
          final canMarkSoldOut =
              isActive && qty > 0 && status != 'Expired';

          return RefreshIndicator(
            onRefresh: _reload,
            color: scheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: imgUrl != null
                          ? Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.local_offer_outlined,
                                size: 56,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          deal['title']?.toString() ?? 'Deal',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ETB ${deal['discounted_price'] ?? '—'}'
                    '  ·  was ${deal['original_price'] ?? '—'}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${deal['quantity_available'] ?? 0} left',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (deal['expiry_date'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Expires ${DateFormat('MMM d, y').format(DateTime.tryParse(deal['expiry_date'].toString())?.toLocal() ?? DateTime.now())}',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Description',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (deal['description']?.toString().trim().isNotEmpty ?? false)
                        ? deal['description'].toString()
                        : 'No description',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: VendorTheme.softShadowFor(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await context.push('/deal/${widget.dealId}/edit');
                            if (mounted) await _reload();
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit deal'),
                        ),
                        const SizedBox(height: 12),
                        if (canMarkSoldOut)
                          OutlinedButton.icon(
                            onPressed: _confirmSoldOut,
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('Mark as sold out'),
                          ),
                        if (canMarkSoldOut) const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _toggleActive(isActive),
                          icon: Icon(
                            isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                          ),
                          label: Text(isActive ? 'Deactivate deal' : 'Activate deal'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
