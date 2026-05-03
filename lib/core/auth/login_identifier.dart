/// Shared parsing for "email or phone" sign-in.
class LoginIdentifier {
  LoginIdentifier._();

  static bool isEmail(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  /// Returns E.164 (leading +) for Supabase / APIs, or null if invalid.
  static String? normalizeToE164(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\s\-\(\).]'), '');
    if (s.isEmpty) return null;
    if (s.startsWith('+')) {
      if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(s)) return null;
      return s;
    }
    final digits = s.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 8 || digits.length > 15) return null;
    return '+$digits';
  }

  static bool isValid(String? raw) => validationError(raw) == null;

  static String? validationError(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Enter your email or phone number.';
    }
    final t = raw.trim();
    if (isEmail(t)) return null;
    if (normalizeToE164(t) != null) return null;
    return 'Use a valid email or phone with country code (e.g. +15551234567).';
  }
}
