// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/notifications_screen.dart
// Screen: User Notifications List & Read Tracker (Rule 20, Rule 27)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/notification_model.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/pressable_neumorphic_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AppNotificationModel> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.getNotifications();
      if (!mounted) return;
      if (res['success'] == true) {
        final list = res['data'] as List<AppNotificationModel>;
        setState(() {
          _notifications = list;
          _unreadCount = res['unreadCount'] as int? ?? list.where((n) => !n.isRead).length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['errorMessage'] as String? ?? 'فشل تحميل الإشعارات';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'خطأ في الاتصال: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotificationModel item) async {
    if (item.isRead) return;

    // Optimistic UI update
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == item.id);
      if (index != -1) {
        _notifications[index] = item.copyWith(isRead: true, readAt: DateTime.now());
        if (_unreadCount > 0) _unreadCount--;
      }
    });

    try {
      final success = await ApiClient.markNotificationRead(item.id);
      if (!success && mounted) {
        // Silently keep or revert if needed
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
    });

    for (final item in unread) {
      await ApiClient.markNotificationRead(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: AppColors.pageBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDark, size: 20),
            onPressed: () => Navigator.of(context).pop(_unreadCount),
          ),
          title: Row(
            children: [
              Text(
                'مركز الإشعارات',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              if (_unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.heroGradientStart,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_unreadCount جديد',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (_unreadCount > 0)
              TextButton.icon(
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.heroGradientStart),
                label: Text(
                  'قراءة الكل',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heroGradientStart,
                  ),
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.heroGradientStart,
          onRefresh: _fetchNotifications,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.heroGradientStart),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.statusOffline),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchNotifications,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heroGradientStart,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.heroGradientStart.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 54,
                  color: AppColors.heroGradientStart,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد إشعارات حالياً',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ستظهر هنا جميع التنبيهات ورسائل الدعم والإشعارات الهامة.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        return _buildNotificationCard(item);
      },
    );
  }

  Widget _buildNotificationCard(AppNotificationModel item) {
    final isUnread = !item.isRead;
    final isSystem = item.type == AppNotificationType.system;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableNeumorphicCard(
        onTap: () => _markAsRead(item),
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: isUnread
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                )
              : null,
          padding: isUnread ? const EdgeInsets.all(4) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon indicator
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSystem
                          ? AppColors.accentYellow.withValues(alpha: 0.2)
                          : (isUnread
                              ? AppColors.heroGradientStart.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSystem ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                      color: isSystem
                          ? const Color(0xFFD97706)
                          : (isUnread ? AppColors.heroGradientStart : AppColors.textMuted),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title and relative time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: GoogleFonts.cairo(
                                  fontSize: 14.5,
                                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.heroGradientStart,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.relativeTimeArabic,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Body content
              Text(
                item.body,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: isUnread ? AppColors.textDark : AppColors.textDark.withValues(alpha: 0.75),
                  height: 1.45,
                ),
              ),
              if (isUnread) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'اضغط لتحديد كمقروء',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.heroGradientStart,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
