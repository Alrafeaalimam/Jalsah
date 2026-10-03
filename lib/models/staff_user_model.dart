// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/staff_user_model.dart
// Model: Staff User & Role Representation
// Master Reference: Rule 14 (Security), Rule 26 (MVP Roles)
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StaffUserModel {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String status;
  final String? email;
  final String? phone;
  final DateTime? createdAt;

  const StaffUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.status = 'ACTIVE',
    this.email,
    this.phone,
    this.createdAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory StaffUserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return StaffUserModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'OPERATOR',
      status: json['status'] as String? ?? 'ACTIVE',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'role': role,
      'status': status,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  /// Arabic display label for the user's role
  String get roleArabic {
    switch (role.toUpperCase()) {
      case 'TENANT_ADMIN':
        return 'مدير';
      case 'OPERATOR':
        return 'مشغّل';
      case 'RESELLER':
        return 'وكيل بيع';
      case 'ACCOUNTANT':
        return 'محاسب';
      case 'SUPER_ADMIN':
        return 'مدير عام';
      default:
        return role;
    }
  }

  /// Accent color for the user's role badge
  Color get roleColor {
    switch (role.toUpperCase()) {
      case 'TENANT_ADMIN':
        return AppColors.heroGradientStart;
      case 'OPERATOR':
        return const Color(0xFF2563EB); // Royal Blue
      case 'RESELLER':
        return const Color(0xFFD97706); // Warm Amber
      case 'ACCOUNTANT':
        return const Color(0xFF0D9488); // Teal
      case 'SUPER_ADMIN':
        return const Color(0xFF7C3AED); // Deep Purple
      default:
        return AppColors.textMuted;
    }
  }

  /// Icon representing user role
  IconData get roleIcon {
    switch (role.toUpperCase()) {
      case 'TENANT_ADMIN':
      case 'SUPER_ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'OPERATOR':
        return Icons.engineering_rounded;
      case 'RESELLER':
        return Icons.storefront_rounded;
      case 'ACCOUNTANT':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  /// Arabic display label for account status
  String get statusArabic {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'نشط';
      case 'INACTIVE':
        return 'معطّل';
      case 'SUSPENDED':
        return 'موقوف';
      default:
        return status;
    }
  }

  /// Color for account status badge
  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.statusOnline;
      case 'INACTIVE':
        return AppColors.statusOffline;
      case 'SUSPENDED':
        return const Color(0xFFEF4444);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffUserModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
