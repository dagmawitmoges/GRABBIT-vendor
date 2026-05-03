import 'dart:io';

Future<String?> readUserDotEnvFile() async {
  try {
    final file = File('.env');
    if (!await file.exists()) return null;
    final s = await file.readAsString();
    return s.trim().isEmpty ? null : s;
  } on FileSystemException {
    return null;
  }
}
