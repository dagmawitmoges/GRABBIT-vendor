import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit_vendor_app/core/network/dio_client.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // clean light background
      body: SafeArea(
        child: FutureBuilder(
          future: DioClient.instance.get('/api/vendor/dashboard'),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong'));
            }

            final data = (snapshot.data as dynamic).data ?? {};
            final stats = data['stats'] ?? {};
            final vendor = data['vendor'] ?? {};

            return RefreshIndicator(
              onRefresh: () async {
                await DioClient.instance.get('/api/vendor/dashboard');
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🔥 HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vendor['business_name'] ?? 'Your Store',
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.store, color: Colors.white),
                        )
                      ],
                    ),

                    const SizedBox(height: 30),

                    /// 📊 STATS
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _DashboardCard(
                          title: 'Total Deals',
                          value: '${stats['totalDeals'] ?? 0}',
                          icon: Icons.local_offer,
                        ),
                        _DashboardCard(
                          title: 'Active Deals',
                          value: '${stats['activeDeals'] ?? 0}',
                          icon: Icons.check_circle,
                        ),
                        _DashboardCard(
                          title: 'Orders',
                          value: '${stats['totalOrders'] ?? 0}',
                          icon: Icons.shopping_bag,
                        ),
                        _DashboardCard(
                          title: 'Revenue',
                          value: 'ETB ${stats['revenue'] ?? 0}',
                          icon: Icons.attach_money,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    /// 🚀 CREATE DEAL CTA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create a new deal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Turn unsold items into profit.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),

                          ElevatedButton(
                            onPressed: () {
                              context.push('/create-deal');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Create Deal'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// 📈 INSIGHTS
                    const Text(
                      'Insights',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'You have ${stats['totalOrders'] ?? 0} orders and ${stats['activeDeals'] ?? 0} active deals running.',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}