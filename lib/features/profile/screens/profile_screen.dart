import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/provider/auth_provider.dart';
import '../../../core/network/dio_client.dart';

const _green = Color(0xFF1DB954);
const _greenLight = Color(0xFFE8F5ED);
const _bg = Color(0xFFF5F8F5);
const _textDark = Color(0xFF0F1F0F);
const _textMuted = Color(0xFF6B7C6B);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<Map<String, dynamic>> _fetchProfile() async {
    final response = await DioClient.instance.get('/api/vendor/profile');
    return response.data is Map<String, dynamic> ? response.data : {};
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700, color: _textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8EDE8)),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _green));
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: () => setState(() => _profileFuture = _fetchProfile()));
          }

          final p = snapshot.data ?? {};

          // VendorProfile fields (vendor_profiles table)
          final businessName = p['business_name'] ?? 'N/A';
          final ownerName    = p['owner_name']    ?? 'N/A';
          final phone        = p['phone']         ?? 'N/A';
          final location     = p['location']      ?? 'N/A';
          final address      = p['address']       ?? 'N/A';
          final businessType = p['business_type'] ?? 'N/A';
          final tin          = p['tin']           ?? 'N/A';
          final branchCount  = (p['branch_count'] ?? 1).toString();
          final createdAt    = _formatDate(p['created_at']);

          // Email lives in the users table — backend must join it.
          // Support two common response shapes:
          //   { user: { email: '...' } }  or  { email: '...' }
          final email = p['user']?['email'] ?? p['email'] ?? 'N/A';

          final initials = _initials(ownerName != 'N/A' ? ownerName : businessName);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Identity card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _greenLight),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: _green,
                      child: Text(initials, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(businessName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
                  const SizedBox(height: 4),
                  Text(ownerName, style: const TextStyle(fontSize: 13.5, color: _textMuted)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(fontSize: 13, color: _textMuted)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(20)),
                    child: Text(businessType, style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              Row(children: [
                _StatCard(label: 'Branches', value: branchCount),
                const SizedBox(width: 12),
                _StatCard(label: 'Member Since', value: createdAt),
              ]),
              const SizedBox(height: 16),

              _InfoCard(title: 'Contact Information', rows: [
                _InfoRow(icon: Icons.phone_outlined,       label: 'Phone',    value: phone),
                _InfoRow(icon: Icons.email_outlined,       label: 'Email',    value: email),
                _InfoRow(icon: Icons.location_on_outlined, label: 'Location', value: location),
                _InfoRow(icon: Icons.home_outlined,        label: 'Address',  value: address),
              ]),
              const SizedBox(height: 12),

              _InfoCard(title: 'Business Details', rows: [
                _InfoRow(icon: Icons.receipt_long_outlined, label: 'TIN',           value: tin),
                _InfoRow(icon: Icons.storefront_outlined,   label: 'Business Type', value: businessType),
                _InfoRow(icon: Icons.calendar_today_outlined, label: 'Joined',      value: createdAt),
              ]),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'V';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(date.toString()));
    } catch (_) {
      return 'N/A';
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _green)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: _textMuted)),
      ]),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});
  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 0.3)),
      const SizedBox(height: 16),
      ...rows,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _green),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
        ]),
      ),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
      const SizedBox(height: 16),
      const Text('Failed to load profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
      const SizedBox(height: 6),
      const Text('Please check your connection', style: TextStyle(color: _textMuted)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}