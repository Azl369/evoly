import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const authCallbackUrl = String.fromEnvironment(
    'SUPABASE_AUTH_CALLBACK_URL',
    defaultValue: 'evoly://auth-callback',
  );

  static String get publishableKey {
    return _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;
  }

  static bool get hasAnyValue => url.isNotEmpty || publishableKey.isNotEmpty;
  static bool get isComplete => url.isNotEmpty && publishableKey.isNotEmpty;
}

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static var _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient? get clientOrNull {
    return _initialized ? Supabase.instance.client : null;
  }

  static Future<void> initialize() async {
    if (!SupabaseRuntimeConfig.hasAnyValue) {
      debugPrint('Supabase sync disabled: no dart-define config found.');
      return;
    }

    if (!SupabaseRuntimeConfig.isComplete) {
      throw StateError(
        'Both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be provided.',
      );
    }

    await Supabase.initialize(
      url: SupabaseRuntimeConfig.url,
      publishableKey: SupabaseRuntimeConfig.publishableKey,
    );
    _initialized = true;
  }
}
