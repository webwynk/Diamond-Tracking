import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_clock.dart';

/// The single [ServerClock]. Created in bootstrap with the Supabase source and
/// overridden there (and in tests).
final Provider<ServerClock> serverClockProvider = Provider<ServerClock>(
  (Ref ref) =>
      throw UnimplementedError('serverClockProvider must be overridden'),
);
