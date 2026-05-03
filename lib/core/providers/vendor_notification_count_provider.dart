import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit_vendor_app/core/data/vendor_repository.dart';

final vendorNotificationCountProvider = FutureProvider<int>((ref) async {
  final list = await VendorRepository().getVendorNotifications();
  return list.length;
});
