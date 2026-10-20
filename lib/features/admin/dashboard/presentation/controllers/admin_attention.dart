import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/live_position.dart';
import '../../../map/presentation/controllers/admin_live_map_state.dart';

/// Why someone is on the "Needs attention" list, most serious first.
enum AttentionReason { fakeGps, noUpdate, lowBattery }

/// Battery percentage under which someone is listed. The same threshold the
/// server uses for its low-battery notification (PRD F12).
const int lowBatteryPercent = 15;

/// One person on the Home's "Needs attention" list, with the single most
/// serious reason.
@immutable
class AttentionItem {
  const AttentionItem({required this.officer, required this.reason});

  final LiveOfficer officer;
  final AttentionReason reason;

  /// The reason in plain words, from what the live feed already knows.
  String get text {
    switch (reason) {
      case AttentionReason.fakeGps:
        return 'Fake GPS flagged';
      case AttentionReason.noUpdate:
        return 'No update · ${officer.lastSeen}';
      case AttentionReason.lowBattery:
        return 'Battery ${officer.position.batteryLevel}%';
    }
  }
}

/// Who needs an admin's attention, from the live feed only: fake GPS first,
/// then people who have gone quiet, then low batteries; by name within a
/// reason. A person appears once, with their most serious reason. Nothing is
/// invented: a missing battery reading never counts as low.
List<AttentionItem> attentionItems(List<LiveOfficer> officers) {
  final items = <AttentionItem>[];
  for (final officer in officers) {
    final battery = officer.position.batteryLevel;
    final AttentionReason? reason;
    if (officer.status == LiveStatus.suspect) {
      reason = AttentionReason.fakeGps;
    } else if (officer.status == LiveStatus.stale) {
      reason = AttentionReason.noUpdate;
    } else if (battery != null && battery < lowBatteryPercent) {
      reason = AttentionReason.lowBattery;
    } else {
      reason = null;
    }
    if (reason != null) {
      items.add(AttentionItem(officer: officer, reason: reason));
    }
  }
  items.sort((a, b) {
    final byReason = a.reason.index.compareTo(b.reason.index);
    if (byReason != 0) return byReason;
    return a.officer.name.toLowerCase().compareTo(b.officer.name.toLowerCase());
  });
  return items;
}
