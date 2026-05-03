import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Reads/writes vendor data in Supabase using your public schema.
class SupabaseVendorData {
  SupabaseVendorData._();

  static SupabaseClient get _c => Supabase.instance.client;

  static String _requireUserId() {
    final id = _c.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('Not signed in');
    }
    return id;
  }

  /// `profiles.role` enum (e.g. VENDOR). Falls back to false if row missing.
  static Future<bool> isVendorProfile(String userId) async {
    final row = await _c
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return false;
    final r = row['role']?.toString().toUpperCase() ?? '';
    return r == 'VENDOR';
  }

  static String _vendorDealsOrFilter(String uid) =>
      'vendor_user_id.eq.$uid,vendor_id.eq.$uid';

  static Future<Map<String, dynamic>> getDashboard() async {
    final uid = _requireUserId();
    final orFilter = _vendorDealsOrFilter(uid);

    final vp = await _c
        .from('vendor_profiles')
        .select('business_name')
        .eq('user_id', uid)
        .maybeSingle();

    final dealsRes = await _c
        .from('deals')
        .select(
          'id, is_active, removed_by_admin, quantity_remaining, discounted_price, expiry_time',
        )
        .or(orFilter);

    final dealsList =
        (dealsRes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final totalDeals = dealsList.length;
    final now = DateTime.now();
    var activeDeals = 0;
    for (final d in dealsList) {
      if (d['removed_by_admin'] == true) continue;
      if (d['is_active'] != true) continue;
      final q = (d['quantity_remaining'] as num?)?.toInt() ?? 0;
      if (q <= 0) continue;
      final exp = d['expiry_time'];
      if (exp != null) {
        final dt = DateTime.tryParse(exp.toString());
        if (dt != null && dt.isBefore(now)) continue;
      }
      activeDeals++;
    }

    final dealIds = dealsList.map((e) => e['id']).whereType<String>().toList();
    num revenue = 0;
    var totalOrders = 0;
    if (dealIds.isNotEmpty) {
      final ordersRes = await _c
          .from('orders')
          .select('total_price')
          .inFilter('deal_id', dealIds);
      final ordersList =
          (ordersRes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      totalOrders = ordersList.length;
      for (final o in ordersList) {
        revenue += (o['total_price'] as num?) ?? 0;
      }
    }

    return {
      'vendor': {
        'business_name': vp?['business_name']?.toString() ?? 'Your Store',
      },
      'stats': {
        'totalDeals': totalDeals,
        'activeDeals': activeDeals,
        'totalOrders': totalOrders,
        'revenue': revenue,
      },
    };
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final uid = _requireUserId();

    final row = await _c
        .from('vendor_profiles')
        .select(
            'business_name, business_description, phone, location, tin, created_at, updated_at')
        .eq('user_id', uid)
        .maybeSingle();

    final prof = await _c
        .from('profiles')
        .select('email, full_name, phone, role')
        .eq('id', uid)
        .maybeSingle();

    final branchesRes =
        await _c.from('vendor_branches').select('id').eq('vendor_user_id', uid);
    final branchCount = (branchesRes as List).length;

    final branchAddr = await _c
        .from('vendor_branches')
        .select('address_detail')
        .eq('vendor_user_id', uid)
        .limit(1)
        .maybeSingle();

    final profMap = prof != null
        ? Map<String, dynamic>.from(prof as Map)
        : <String, dynamic>{};

    if (row == null) {
      return {
        'business_name': 'N/A',
        'owner_name': profMap['full_name']?.toString() ?? 'N/A',
        'phone': profMap['phone']?.toString() ?? 'N/A',
        'location': 'N/A',
        'address': 'N/A',
        'business_type': profMap['role']?.toString() ?? 'Vendor',
        'tin': 'N/A',
        'branch_count': branchCount,
        'created_at': null,
        'email': profMap['email']?.toString() ??
            _c.auth.currentUser?.email ??
            'N/A',
      };
    }

    final vp = Map<String, dynamic>.from(row as Map);

    return {
      'business_name': vp['business_name'] ?? 'N/A',
      'owner_name': profMap['full_name']?.toString() ?? 'N/A',
      'phone': vp['phone']?.toString() ??
          profMap['phone']?.toString() ??
          'N/A',
      'location': vp['location']?.toString() ?? 'N/A',
      'address': branchAddr?['address_detail']?.toString() ?? 'N/A',
      'business_type': profMap['role']?.toString() ?? 'Vendor',
      'tin': vp['tin']?.toString() ?? 'N/A',
      'branch_count': branchCount,
      'created_at': vp['created_at'],
      'email': profMap['email']?.toString() ??
          _c.auth.currentUser?.email ??
          'N/A',
    };
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _requireUserId();
    final patch = <String, dynamic>{};
    for (final e in [
      'business_name',
      'business_description',
      'phone',
      'location',
      'tin',
    ]) {
      if (data.containsKey(e)) patch[e] = data[e];
    }
    if (patch.isEmpty) return;
    patch['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _c.from('vendor_profiles').update(patch).eq('user_id', uid);
  }

  static Map<String, dynamic> _normalizeDealRow(Map<String, dynamic> d) {
    return {
      ...d,
      'quantity_available': d['quantity_remaining'],
      'expiry_date': d['expiry_time'],
    };
  }

  static Future<List<Map<String, dynamic>>> getDeals() async {
    final uid = _requireUserId();
    final res = await _c
        .from('deals')
        .select('*')
        .or(_vendorDealsOrFilter(uid))
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => _normalizeDealRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static void _ensureDealRowOwned(Map<String, dynamic> map, String uid) {
    final vu = map['vendor_user_id']?.toString();
    final vid = map['vendor_id']?.toString();
    if (vu != uid && vid != uid) {
      throw StateError('You can only manage your own deals');
    }
  }

  static Future<void> _assertDealOwnedByVendor(String dealId) async {
    final uid = _requireUserId();
    final row = await _c
        .from('deals')
        .select('id, vendor_user_id, vendor_id')
        .eq('id', dealId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Deal not found');
    }
    _ensureDealRowOwned(Map<String, dynamic>.from(row as Map), uid);
  }

  static Future<Map<String, dynamic>> getDealById(String dealId) async {
    final uid = _requireUserId();
    final res = await _c.from('deals').select('*').eq('id', dealId).maybeSingle();
    if (res == null) {
      throw StateError('Deal not found');
    }
    final map = Map<String, dynamic>.from(res as Map);
    _ensureDealRowOwned(map, uid);
    return _normalizeDealRow(map);
  }

  static Future<void> updateDeal({
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
    await _assertDealOwnedByVendor(dealId);
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (description != null) patch['description'] = description.isEmpty ? null : description;
    if (originalPrice != null) patch['original_price'] = originalPrice;
    if (discountedPrice != null) patch['discounted_price'] = discountedPrice;
    if (quantityRemaining != null) {
      patch['quantity_remaining'] = quantityRemaining;
    }
    if (categoryId != null) patch['category_id'] = categoryId;
    if (locationId != null) patch['location_id'] = locationId;
    if (expiryTime != null) {
      patch['expiry_time'] = expiryTime.toUtc().toIso8601String();
    }
    if (isActive != null) patch['is_active'] = isActive;
    if (images != null) patch['images'] = images;
    if (patch.isEmpty) return;
    await _c.from('deals').update(patch).eq('id', dealId);
  }

  static Future<void> markDealSoldOut(String dealId) async {
    await updateDeal(dealId: dealId, quantityRemaining: 0);
  }

  static Future<void> uploadDealImageAndSet({
    required String dealId,
    required Uint8List imageBytes,
    required String imageFileName,
  }) async {
    await _assertDealOwnedByVendor(dealId);
    final uid = _requireUserId();
    final bucket = Env.supabaseDealImagesBucket;
    final safeName = imageFileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final storagePath =
        '$uid/${dealId}_${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _c.storage.from(bucket).uploadBinary(
          storagePath,
          imageBytes,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final publicUrl = _c.storage.from(bucket).getPublicUrl(storagePath);
    await _c.from('deals').update({'images': [publicUrl]}).eq('id', dealId);
  }

  static Future<List<String>> _fetchVendorDealIds(String uid) async {
    final dealsRes = await _c
        .from('deals')
        .select('id')
        .or(_vendorDealsOrFilter(uid));
    return (dealsRes as List)
        .map((e) => (e as Map)['id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .toList();
  }

  static Map<String, dynamic> _normalizeOrderRow(Map<String, dynamic> row) {
    final m = Map<String, dynamic>.from(row);
    final d = m['deals'];
    void applyDealMap(Map dealMap) {
      m['deal_title'] = dealMap['title'] ?? m['deal_title'];
      m['deal_discounted_price'] =
          dealMap['discounted_price'] ?? m['deal_discounted_price'];
      final imgs = dealMap['images'];
      if (imgs is List && imgs.isNotEmpty) {
        final first = imgs.first;
        if (first is String && first.isNotEmpty) {
          m['deal_image_url'] = first;
        }
      }
    }

    if (d is Map) {
      applyDealMap(d);
      m.remove('deals');
    } else if (d is List && d.isNotEmpty && d.first is Map) {
      applyDealMap(d.first as Map);
      m.remove('deals');
    }
    return m;
  }

  static Future<void> _assertOrderManagedByVendor(String orderId) async {
    final uid = _requireUserId();
    final orderRes =
        await _c.from('orders').select('id, deal_id').eq('id', orderId).maybeSingle();
    if (orderRes == null) {
      throw StateError('Order not found');
    }
    final order = Map<String, dynamic>.from(orderRes as Map);
    final dealId = order['deal_id']?.toString();
    if (dealId == null || dealId.isEmpty) {
      throw StateError('Invalid order');
    }
    final dealRes = await _c
        .from('deals')
        .select('vendor_user_id, vendor_id')
        .eq('id', dealId)
        .maybeSingle();
    if (dealRes == null) {
      throw StateError('Deal not found');
    }
    final deal = Map<String, dynamic>.from(dealRes as Map);
    _ensureDealRowOwned(deal, uid);
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final uid = _requireUserId();
    final dealIds = await _fetchVendorDealIds(uid);
    if (dealIds.isEmpty) return [];

    final res = await _c
        .from('orders')
        .select('*, deals(title)')
        .inFilter('deal_id', dealIds)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => _normalizeOrderRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    await _assertOrderManagedByVendor(orderId);
    final res = await _c
        .from('orders')
        .select('*, deals(title, discounted_price, images)')
        .eq('id', orderId)
        .single();
    return _normalizeOrderRow(Map<String, dynamic>.from(res as Map));
  }

  /// Vendor accepts a customer order (e.g. pending → accepted).
  static Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _assertOrderManagedByVendor(orderId);
    await _c.from('orders').update({'status': status}).eq('id', orderId);
  }

  static Future<List<Map<String, dynamic>>> getVendorNotifications() async {
    final uid = _requireUserId();
    final res = await _c
        .from('vendor_notifications')
        .select('*')
        .eq('vendor_user_id', uid)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final res =
        await _c.from('categories').select('id, name, icon').order('name');
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getLocations() async {
    final res = await _c
        .from('locations')
        .select('id, sub_city, city, country, sort_order')
        .order('sort_order', ascending: true);
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> createDeal({
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
    final uid = _requireUserId();
    final bucket = Env.supabaseDealImagesBucket;
    final safeName = imageFileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final storagePath =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _c.storage.from(bucket).uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    final publicUrl = _c.storage.from(bucket).getPublicUrl(storagePath);

    await _c.from('deals').insert({
      'vendor_id': uid,
      'vendor_user_id': uid,
      'category_id': categoryId,
      'location_id': locationId,
      'title': title,
      'description': description.isEmpty ? null : description,
      'original_price': originalPrice,
      'discounted_price': discountedPrice,
      'quantity_total': quantity,
      'quantity_remaining': quantity,
      'start_time': DateTime.now().toUtc().toIso8601String(),
      'expiry_time': expiryTime.toUtc().toIso8601String(),
      'images': [publicUrl],
      'is_active': true,
      'removed_by_admin': false,
    });
  }
}
