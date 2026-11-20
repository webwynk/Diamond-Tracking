/// One in-app notification (the same text is pushed to the phone).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.requestId,
    this.readAt,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final Map<String, dynamic> data =
        (row['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return AppNotification(
      id: (row['id'] as num).toInt(),
      kind: row['kind'] as String,
      title: row['title'] as String,
      body: row['body'] as String?,
      requestId: (data['request_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      readAt: row['read_at'] == null
          ? null
          : DateTime.parse(row['read_at'] as String).toUtc(),
    );
  }

  final int id;
  final String kind;
  final String title;
  final String? body;

  /// The request it is about, if any (a tap opens it).
  final int? requestId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
}
