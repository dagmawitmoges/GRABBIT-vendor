import 'package:flutter/material.dart';
import 'package:grabbit_vendor_app/core/network/dio_client.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  String filter = 'all';

  Future<dynamic> _fetchDeals() async {
    final res = await DioClient.instance.get('/api/vendor/deals');
    return res.data;
  }

  String _getStatus(Map deal) {
    final isActive = deal['is_active'] == true;
    final expiry = DateTime.tryParse(deal['expiry_date'] ?? '');

    if (!isActive) return 'Inactive';
    if (expiry != null && expiry.isBefore(DateTime.now())) return 'Expired';

    final qty = deal['quantity_available'] ?? 0;
    if (qty == 0) return 'Sold Out';

    return 'Active';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Sold Out':
        return Colors.orange;
      case 'Expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// 🔹 APP BAR
      appBar: AppBar(
        title: const Text('Your Deals'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),

      /// 🔹 FLOATING CTA (IMPORTANT)
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        onPressed: () {
          // TODO: navigate to create deal
        },
        label: const Text('Create Deal'),
        icon: const Icon(Icons.add),
      ),

      body: FutureBuilder(
        future: _fetchDeals(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data;
          final deals = raw is List ? raw : (raw['deals'] ?? []);

          if (deals.isEmpty) {
            return _EmptyState();
          }

          final filteredDeals = deals.where((d) {
            if (filter == 'all') return true;
            return _getStatus(d).toLowerCase() == filter;
          }).toList();

          return Column(
            children: [
              /// 🔹 FILTER TABS
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _FilterChip('All', 'all'),
                    _FilterChip('Active', 'active'),
                    _FilterChip('Sold Out', 'sold out'),
                    _FilterChip('Expired', 'expired'),
                  ],
                ),
              ),

              /// 🔹 LIST
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDeals.length,
                  itemBuilder: (_, index) {
                    final deal = filteredDeals[index];
                    final status = _getStatus(deal);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// 🔹 TITLE + STATUS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  deal['title'] ?? 'Untitled deal',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            ],
                          ),

                          const SizedBox(height: 10),

                          /// 🔹 PRICE + QTY
                          Text(
                            'ETB ${deal['discounted_price']} • ${deal['quantity_available']} left',
                            style: TextStyle(color: Colors.grey[700]),
                          ),

                          const SizedBox(height: 12),

                          /// 🔹 ACTIONS
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  // TODO: edit deal
                                },
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () {
                                  // TODO: toggle active
                                },
                                child: const Text('Deactivate'),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                              )
                            ],
                          )
                        ],
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

  /// 🔹 FILTER CHIP
  Widget _FilterChip(String label, String value) {
    final isSelected = filter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.green,
        onSelected: (_) {
          setState(() => filter = value);
        },
      ),
    );
  }
}

/// 🔹 EMPTY STATE
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_offer, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No deals yet'),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {},
            child: const Text('Create your first deal'),
          )
        ],
      ),
    );
  }
}