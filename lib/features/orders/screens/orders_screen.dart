import 'package:flutter/material.dart';
import 'package:grabbit_vendor_app/core/network/dio_client.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: FutureBuilder(
        future: DioClient.instance.get('/api/vendor/orders'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load orders. Please try again later.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          final raw = (snapshot.data as dynamic).data;
          final orders = raw is List
              ? raw
              : (raw['orders'] as List<dynamic>? ?? []);

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders found yet. Start receiving orders from your deals.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final order = orders[index];
              return Card(
                color: const Color(0xFF112A46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  title: Text(
                    order['deal_title'] ?? 'Unknown deal',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Qty: ${order['quantity'] ?? '0'} • ${order['status'] ?? 'Pending'}',
                  ),
                  trailing: Text(
                    'ETB ${order['total_price'] ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
