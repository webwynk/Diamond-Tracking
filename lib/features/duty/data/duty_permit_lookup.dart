import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/ist.dart';

/// Whether the admin allowed [userId] a duty on for [day] that is not used
/// yet. The one copy of this lookup, for the employee's Home and the admin's
/// user page (L79).
Future<bool> hasUnusedDutyPermit(
  SupabaseClient client,
  String userId,
  DateTime day,
) async {
  final Map<String, dynamic>? row = await client
      .from('duty_permits')
      .select('user_id')
      .eq('user_id', userId)
      .eq('day', isoDate(day))
      .isFilter('used_at', null)
      .maybeSingle();
  return row != null;
}
