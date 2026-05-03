import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'user_env_stub.dart' if (dart.library.io) 'user_env_io.dart' as user_env;

/// Loads [`.env.example`] from assets, then merges project-root [`.env`] on
/// mobile/desktop (IO). `--dart-define` / `String.fromEnvironment` in [Env]
/// still override these at build time when non-empty.
Future<void> loadAppEnv() async {
  var example = '';
  try {
    example = await rootBundle.loadString('.env.example');
  } catch (_) {}

  final userOverride = await user_env.readUserDotEnvFile();

  dotenv.loadFromString(
    envString: example,
    overrideWith: userOverride != null ? [userOverride] : const [],
    isOptional: true,
  );
}
