/// Plain-words age of something, for lists: "Just now", "3 min ago",
/// "2 h 5 min ago", "3 d ago".
///
/// Display only. The age must be measured against the server's clock where it
/// matters; this only words it.
abstract final class TimeAgo {
  const TimeAgo._();

  static String format(Duration age) {
    if (age.isNegative || age.inSeconds < 60) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) {
      final minutes = age.inMinutes % 60;
      return minutes == 0
          ? '${age.inHours} h ago'
          : '${age.inHours} h $minutes min ago';
    }
    return '${age.inDays} d ago';
  }
}
