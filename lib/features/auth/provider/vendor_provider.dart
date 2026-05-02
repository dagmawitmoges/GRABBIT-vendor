import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/data/vendor_repository.dart';

final vendorProvider =
    StateNotifierProvider<VendorNotifier, VendorState>((ref) {
  return VendorNotifier();
});

class VendorState {
  final bool isLoading;
  final Map<String, dynamic>? dashboard;
  final List<dynamic>? deals;
  final List<dynamic>? orders;

  VendorState({
    this.isLoading = false,
    this.dashboard,
    this.deals,
    this.orders,
  });

  VendorState copyWith({
    bool? isLoading,
    Map<String, dynamic>? dashboard,
    List<dynamic>? deals,
    List<dynamic>? orders,
  }) {
    return VendorState(
      isLoading: isLoading ?? this.isLoading,
      dashboard: dashboard ?? this.dashboard,
      deals: deals ?? this.deals,
      orders: orders ?? this.orders,
    );
  }
}

class VendorNotifier extends StateNotifier<VendorState> {
  final VendorRepository repo = VendorRepository();

  VendorNotifier() : super(VendorState());

  // 📊 Load dashboard
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true);

    try {
      final data = await repo.getDashboard();

      state = state.copyWith(
        isLoading: false,
        dashboard: data,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  // 🏷 Load deals
  Future<void> loadDeals() async {
    try {
      final data = await repo.getDeals();
      state = state.copyWith(deals: data);
    } catch (_) {}
  }

  // 📦 Load orders
  Future<void> loadOrders() async {
    try {
      final data = await repo.getOrders();
      state = state.copyWith(orders: data);
    } catch (_) {}
  }
}