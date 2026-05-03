/// Values stored in `orders.status` (match your Supabase schema).
abstract final class OrderStatus {
  static const String created = 'created';
  /// After vendor accepts — customer typically sees this as in progress / pending fulfillment.
  static const String pending = 'pending';
  static const String completed = 'completed';
  /// Use the same spelling as your DB column (US: canceled, UK: cancelled, or typo cancled).
  static const String canceled = 'canceled';

  static String normalized(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty ||
        s == 'placed' ||
        s == 'new' ||
        s == 'awaiting_vendor' ||
        s == 'awaiting_confirmation') {
      return created;
    }
    if (s == 'accepted') {
      return pending;
    }
    if (s == 'cancelled' || s == 'cancled') {
      return canceled;
    }
    return s;
  }

  static String label(String? raw) {
    switch (normalized(raw)) {
      case created:
        return 'Created';
      case pending:
        return 'Pending';
      case completed:
        return 'Completed';
      case canceled:
        return 'Canceled';
      default:
        final t = raw?.toString().trim();
        if (t == null || t.isEmpty) return 'Created';
        return t[0].toUpperCase() +
            t.substring(1).toLowerCase().replaceAll('_', ' ');
    }
  }

  /// Vendor can accept (moves to [pending] for the customer view).
  static bool canVendorAccept(String? raw) => normalized(raw) == created;

  /// Vendor can mark fulfilled after accepting.
  static bool canVendorMarkCompleted(String? raw) =>
      normalized(raw) == pending;

  static bool canVendorCancel(String? raw) {
    final n = normalized(raw);
    return n == created || n == pending;
  }
}
