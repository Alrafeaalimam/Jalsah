// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/notification_model.dart
// Model: In-App Notification & Notification Read Status
// ============================================================================

enum AppNotificationType { manual, system }

class AppNotificationModel {
  final String id;
  final String? tenantId;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const AppNotificationModel({
    required this.id,
    this.tenantId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    AppNotificationType parsedType = AppNotificationType.manual;
    final typeStr = json['type']?.toString().toUpperCase();
    if (typeStr == 'SYSTEM') {
      parsedType = AppNotificationType.system;
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (json['createdAt'] != null) {
      final parsed = DateTime.tryParse(json['createdAt'].toString());
      if (parsed != null) parsedCreatedAt = parsed;
    }

    DateTime? parsedReadAt;
    if (json['readAt'] != null) {
      parsedReadAt = DateTime.tryParse(json['readAt'].toString());
    }

    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: parsedType,
      createdAt: parsedCreatedAt,
      isRead: json['isRead'] == true,
      readAt: parsedReadAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'title': title,
      'body': body,
      'type': type == AppNotificationType.system ? 'SYSTEM' : 'MANUAL',
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? tenantId,
    String? title,
    String? body,
    AppNotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Relative human-readable Arabic time (e.g. "منذ 5 دقائق", "منذ ساعة", "اليوم")
  String get relativeTimeArabic {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      if (m == 1) return 'منذ دقيقة';
      if (m == 2) return 'منذ دقيقتين';
      if (m >= 3 && m <= 10) return 'منذ $m دقائق';
      return 'منذ $m دقيقة';
    } else if (difference.inHours < 24) {
      final h = difference.inHours;
      if (h == 1) return 'منذ ساعة';
      if (h == 2) return 'منذ ساعتين';
      if (h >= 3 && h <= 10) return 'منذ $h ساعات';
      return 'منذ $h ساعة';
    } else if (difference.inDays < 7) {
      final d = difference.inDays;
      if (d == 1) return 'أمس';
      if (d == 2) return 'منذ يومين';
      if (d >= 3 && d <= 10) return 'منذ $d أيام';
      return 'منذ $d يوماً';
    } else {
      return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    }
  }
}
