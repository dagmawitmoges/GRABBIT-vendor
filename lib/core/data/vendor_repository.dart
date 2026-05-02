import '../../../core/network/dio_client.dart';

class VendorRepository {
  final dio = DioClient.instance;

  // 📊 Dashboard
  Future<Map<String, dynamic>> getDashboard() async {
    final res = await dio.get('/api/vendor/dashboard');
    return res.data;
  }

  // 👤 Profile
  Future<Map<String, dynamic>> getProfile() async {
    final res = await dio.get('/api/vendor/profile');
    return res.data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await dio.put('/api/vendor/profile', data: data);
    return res.data;
  }

  // 🏷 Deals
  Future<List<dynamic>> getDeals() async {
    final res = await dio.get('/api/vendor/deals');
    return res.data;
  }

  // 📦 Orders
  Future<List<dynamic>> getOrders() async {
    final res = await dio.get('/api/vendor/orders');
    return res.data;
  }

  // 🔔 Notifications
  Future<List<dynamic>> getNotifications() async {
    final res = await dio.get('/api/vendor/notifications');
    return res.data;
  }
}