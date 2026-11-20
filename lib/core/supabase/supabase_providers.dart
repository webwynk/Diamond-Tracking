import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_id.dart';

/// The Supabase client. Only data classes use it; screens use repositories.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);

/// This install's id for the one-phone-at-a-time rule.
final Provider<DeviceIdStore> deviceIdStoreProvider = Provider<DeviceIdStore>(
  (Ref ref) => DeviceIdStore(),
);
