import 'package:flutter/material.dart';
import 'package:grabbit_vendor_app/core/data/vendor_repository.dart';
import 'package:grabbit_vendor_app/core/theme/vendor_theme.dart';
import 'package:grabbit_vendor_app/features/orders/order_status.dart';
import 'package:grabbit_vendor_app/router/app_shell.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return VendorRepository().getOrderById(widget.orderId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Color _statusColor(String? status, ColorScheme scheme) {
    switch (OrderStatus.normalized(status)) {
      case OrderStatus.created:
        return scheme.primary;
      case OrderStatus.pending:
        return const Color(0xFFE67E22);
      case OrderStatus.completed:
        return const Color(0xFF2D6A4F);
      case OrderStatus.canceled:
        return scheme.error;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  Future<void> _acceptOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this order?'),
        content: const Text(
          'The customer will see the order as Pending while you prepare or deliver it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept order'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await VendorRepository().updateOrderStatus(
        orderId: widget.orderId,
        status: OrderStatus.pending,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order accepted — status is now Pending for the customer')),
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

  Future<void> _completeOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark order completed?'),
        content: const Text(
          'This marks the order as completed. The customer will see it as finished.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark completed'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await VendorRepository().updateOrderStatus(
        orderId: widget.orderId,
        status: OrderStatus.completed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked completed')),
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

  Future<void> _cancelOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The order will be marked as canceled. This should be used if you cannot fulfill it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await VendorRepository().updateOrderStatus(
        orderId: widget.orderId,
        status: OrderStatus.canceled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order canceled')),
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

          final order = snapshot.data!;
          final status = order['status']?.toString();
          final normalized = OrderStatus.normalized(status);
          final canAccept = OrderStatus.canVendorAccept(status);
          final canComplete = OrderStatus.canVendorMarkCompleted(status);
          final canCancel = OrderStatus.canVendorCancel(status);
          final statusColor = _statusColor(status, scheme);
          final title = order['deal_title']?.toString() ?? 'Order';
          final imgUrl = order['deal_image_url']?.toString();
          final created = order['created_at'];

          return RefreshIndicator(
            onRefresh: _reload,
            color: scheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
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
                          OrderStatus.label(status),
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
                    'ETB ${order['total_price'] ?? '—'}',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DetailLine(
                    label: 'Quantity',
                    value: '${order['quantity'] ?? '—'}',
                  ),
                  if (order['deal_discounted_price'] != null) ...[
                    const SizedBox(height: 4),
                    _DetailLine(
                      label: 'Deal price',
                      value: 'ETB ${order['deal_discounted_price']}',
                    ),
                  ],
                  if (created != null) ...[
                    const SizedBox(height: 4),
                    _DetailLine(
                      label: 'Placed',
                      value: _formatDate(created),
                    ),
                  ],
                  if (order['id'] != null) ...[
                    const SizedBox(height: 4),
                    _DetailLine(
                      label: 'Order ID',
                      value: order['id'].toString(),
                    ),
                  ],
                  for (final key in [
                    'customer_name',
                    'customer_phone',
                    'delivery_address',
                    'notes',
                    'pickup_notes',
                  ])
                    if (order[key] != null &&
                        order[key].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _DetailLine(
                        label: _labelForKey(key),
                        value: order[key].toString(),
                      ),
                    ],
                  const SizedBox(height: 24),
                  if (canAccept || canComplete || canCancel)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: VendorTheme.softShadowFor(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (canAccept) ...[
                            FilledButton.icon(
                              onPressed: _acceptOrder,
                              icon: const Icon(Icons.how_to_reg_outlined),
                              label: const Text('Accept order'),
                            ),
                            if (canCancel) const SizedBox(height: 12),
                          ],
                          if (canComplete) ...[
                            FilledButton.icon(
                              onPressed: _completeOrder,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark completed'),
                            ),
                            if (canCancel) const SizedBox(height: 12),
                          ],
                          if (canCancel)
                            OutlinedButton.icon(
                              onPressed: _cancelOrder,
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel order'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error,
                                side: BorderSide(
                                  color:
                                      scheme.error.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Text(
                      normalized == OrderStatus.pending
                          ? 'This order is pending for the customer.'
                          : normalized == OrderStatus.completed
                              ? 'This order is completed.'
                              : normalized == OrderStatus.canceled
                                  ? 'This order was canceled.'
                                  : 'This order cannot be updated.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
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

  static String _formatDate(dynamic raw) {
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('MMM d, y • HH:mm').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  static String _labelForKey(String key) {
    switch (key) {
      case 'customer_name':
        return 'Customer';
      case 'customer_phone':
        return 'Phone';
      case 'delivery_address':
        return 'Delivery address';
      case 'notes':
        return 'Notes';
      case 'pickup_notes':
        return 'Pickup notes';
      default:
        return key;
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
