import 'dart:typed_data';

import '../config/env.dart';
import '../network/dio_client.dart';
import 'supabase_vendor_data.dart';

class VendorRepository {
  final dio = DioClient.instance;

  Future<Map<String, dynamic>> getDashboard() async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getDashboard();
    }
    final res = await dio.get('/api/vendor/dashboard');
    return _coerceMap(res.data);
  }

  Future<Map<String, dynamic>> getProfile() async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getProfile();
    }
    final res = await dio.get('/api/vendor/profile');
    return _coerceMap(res.data);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (Env.hasSupabase) {
      await SupabaseVendorData.updateProfile(data);
      return;
    }
    await dio.put('/api/vendor/profile', data: data);
  }

  Future<Map<String, dynamic>> getDealById(String dealId) async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getDealById(dealId);
    }
    final res = await dio.get('/api/vendor/deals/$dealId');
    return _coerceMap(res.data);
  }

  Future<List<Map<String, dynamic>>> getDeals() async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getDeals();
    }
    final res = await dio.get('/api/vendor/deals');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (data is Map && data['deals'] is List) {
      return (data['deals'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getOrderById(orderId);
    }
    final res = await dio.get('/api/vendor/orders/$orderId');
    return _coerceMap(res.data);
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    if (Env.hasSupabase) {
      await SupabaseVendorData.updateOrderStatus(
        orderId: orderId,
        status: status,
      );
      return;
    }
    await dio.patch('/api/vendor/orders/$orderId', data: {'status': status});
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getOrders();
    }
    final res = await dio.get('/api/vendor/orders');
    final raw = res.data;
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (raw is Map && raw['orders'] is List) {
      return (raw['orders'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getVendorNotifications() async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getVendorNotifications();
    }
    final res = await dio.get('/api/vendor/notifications');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getCategories();
    }
    throw UnsupportedError('Categories are loaded from Supabase only.');
  }

  Future<List<Map<String, dynamic>>> getLocations() async {
    if (Env.hasSupabase) {
      return SupabaseVendorData.getLocations();
    }
    throw UnsupportedError('Locations are loaded from Supabase only.');
  }

  Future<void> createDeal({
    required String title,
    required String description,
    required num originalPrice,
    required num discountedPrice,
    required int quantity,
    required String categoryId,
    required String locationId,
    required DateTime expiryTime,
    required Uint8List imageBytes,
    required String imageFileName,
  }) async {
    if (Env.hasSupabase) {
      await SupabaseVendorData.createDeal(
        title: title,
        description: description,
        originalPrice: originalPrice,
        discountedPrice: discountedPrice,
        quantity: quantity,
        categoryId: categoryId,
        locationId: locationId,
        expiryTime: expiryTime,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
      );
      return;
    }
    throw UnsupportedError('Create deal via Supabase only in this project.');
  }

  Future<void> updateDeal({
    required String dealId,
    String? title,
    String? description,
    num? originalPrice,
    num? discountedPrice,
    int? quantityRemaining,
    String? categoryId,
    String? locationId,
    DateTime? expiryTime,
    bool? isActive,
    List<String>? images,
  }) async {
    if (Env.hasSupabase) {
      await SupabaseVendorData.updateDeal(
        dealId: dealId,
        title: title,
        description: description,
        originalPrice: originalPrice,
        discountedPrice: discountedPrice,
        quantityRemaining: quantityRemaining,
        categoryId: categoryId,
        locationId: locationId,
        expiryTime: expiryTime,
        isActive: isActive,
        images: images,
      );
      return;
    }
    await dio.patch('/api/vendor/deals/$dealId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (originalPrice != null) 'original_price': originalPrice,
      if (discountedPrice != null) 'discounted_price': discountedPrice,
      if (quantityRemaining != null) 'quantity_remaining': quantityRemaining,
      if (categoryId != null) 'category_id': categoryId,
      if (locationId != null) 'location_id': locationId,
      if (expiryTime != null) 'expiry_time': expiryTime.toIso8601String(),
      if (isActive != null) 'is_active': isActive,
      if (images != null) 'images': images,
    });
  }

  Future<void> markDealSoldOut(String dealId) async {
    if (Env.hasSupabase) {
      await SupabaseVendorData.markDealSoldOut(dealId);
      return;
    }
    await dio.patch('/api/vendor/deals/$dealId', data: {'quantity_remaining': 0});
  }

  Future<void> replaceDealImage({
    required String dealId,
    required Uint8List imageBytes,
    required String imageFileName,
  }) async {
    if (Env.hasSupabase) {
      await SupabaseVendorData.uploadDealImageAndSet(
        dealId: dealId,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
      );
      return;
    }
    throw UnsupportedError('Replace deal image via Supabase only.');
  }

  static Map<String, dynamic> _coerceMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}
