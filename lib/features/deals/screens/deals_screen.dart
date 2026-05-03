import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit_vendor_app/core/data/vendor_repository.dart';
import 'package:grabbit_vendor_app/core/theme/vendor_theme.dart';
import 'package:grabbit_vendor_app/router/app_shell.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  String filter = 'all';
  late Future<List<Map<String, dynamic>>> _dealsFuture;

  @override
  void initState() {
    super.initState();
    _dealsFuture = _fetchDeals();
  }

  Future<List<Map<String, dynamic>>> _fetchDeals() async {
    return VendorRepository().getDeals();
  }

  void _reloadDeals() {
    setState(() {
      _dealsFuture = _fetchDeals();
    });
  }

  String _getStatus(Map deal) {
    final isActive = deal['is_active'] == true;
    final expiry = DateTime.tryParse(deal['expiry_date']?.toString() ?? '');

    if (!isActive) return 'Inactive';
    if (expiry != null && expiry.isBefore(DateTime.now())) return 'Expired';

    final qty = deal['quantity_available'] ?? 0;
    if (qty == 0) return 'Sold Out';

    return 'Active';
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'Active':
        return scheme.primary;
      case 'Sold Out':
        return const Color(0xFFE67E22);
      case 'Expired':
        return scheme.error;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: appShellBodyBottomPadding(context) -
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/create-deal'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New deal'),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final deals = snapshot.data ?? [];

          if (deals.isEmpty) {
            return _EmptyState(onCreate: () => context.push('/create-deal'));
          }

          final filteredDeals = deals.where((d) {
            if (filter == 'all') return true;
            return _getStatus(d).toLowerCase() == filter;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  children: [
                    _FilterChip(
                      label: 'All',
                      value: 'all',
                      selected: filter,
                      onSelect: (v) => setState(() => filter = v),
                    ),
                    _FilterChip(
                      label: 'Active',
                      value: 'active',
                      selected: filter,
                      onSelect: (v) => setState(() => filter = v),
                    ),
                    _FilterChip(
                      label: 'Sold out',
                      value: 'sold out',
                      selected: filter,
                      onSelect: (v) => setState(() => filter = v),
                    ),
                    _FilterChip(
                      label: 'Expired',
                      value: 'expired',
                      selected: filter,
                      onSelect: (v) => setState(() => filter = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredDeals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No deals match this filter.',
                            style: textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    appShellBodyBottomPadding(context),
                  ),
                  itemCount: filteredDeals.length,
                  itemBuilder: (_, index) {
                    final deal = filteredDeals[index];
                    final status = _getStatus(deal);
                    final statusColor = _statusColor(status, scheme);

                    final dealId = deal['id']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: dealId.isEmpty
                              ? null
                              : () async {
                                  await context.push('/deal/$dealId');
                                  if (context.mounted) _reloadDeals();
                                },
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: VendorTheme.softShadowFor(context),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          deal['title']?.toString() ??
                                              'Untitled deal',
                                          style: textTheme.titleSmall
                                              ?.copyWith(
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
                                          color: statusColor.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status,
                                          style: textTheme.labelMedium
                                              ?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'ETB ${deal['discounted_price']} • ${deal['quantity_available']} left',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'View details',
                                        style: textTheme.labelLarge?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final String value;
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOn = selected == value;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: isOn ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => onSelect(value),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isOn
                    ? scheme.primary
                    : scheme.outline.withValues(alpha: 0.5),
              ),
              boxShadow: isOn ? null : VendorTheme.softShadowFor(context),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isOn ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_rounded,
              size: 72,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 20),
            Text(
              'No deals yet',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first deal and reach hungry customers.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create your first deal'),
            ),
          ],
        ),
      ),
    );
  }
}
