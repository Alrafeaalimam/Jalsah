// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/card_model.dart
// Model: Hotspot Card Representation adhering to Backend Schema & State Machine
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CardModel {
  final String id;
  final String username;
  final String password;
  final String status;
  final String? batchId;
  final String? packageId;
  final double price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CardModel({
    required this.id,
    required this.username,
    required this.password,
    required this.status,
    this.batchId,
    this.packageId,
    this.price = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return CardModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      status: json['status'] as String? ?? 'GENERATED',
      batchId: json['batchId'] as String?,
      packageId: json['packageId'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'status': status,
      if (batchId != null) 'batchId': batchId,
      if (packageId != null) 'packageId': packageId,
      'price': price,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Arabic display label for card status adhering to CardStateMachine
  String get statusTextArabic {
    switch (status.toUpperCase()) {
      case 'GENERATED':
        return 'تم التوليد';
      case 'AVAILABLE':
        return 'متاح للبيع';
      case 'SOLD':
        return 'تم البيع';
      case 'ACTIVE':
        return 'نشط';
      case 'EXPIRED':
        return 'منتهي';
      case 'CANCELLED':
        return 'ملغي';
      case 'SUSPENDED':
        return 'معلق';
      case 'REVOKED':
        return 'مسحوب';
      default:
        return status;
    }
  }

  /// Visual color badge for card status
  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'GENERATED':
        return const Color(0xFFF59E0B); // Amber / Warm Orange
      case 'AVAILABLE':
        return AppColors.statusOnline; // Green
      case 'SOLD':
        return const Color(0xFF3B82F6); // Blue
      case 'ACTIVE':
        return const Color(0xFF10B981); // Emerald
      case 'EXPIRED':
        return AppColors.textMuted; // Grey
      case 'CANCELLED':
        return AppColors.statusOffline; // Red
      case 'SUSPENDED':
        return const Color(0xFFEF4444); // Rose
      case 'REVOKED':
        return const Color(0xFF6B7280); // Dark grey
      default:
        return AppColors.heroGradientEnd;
    }
  }

  String get formattedPrice {
    final isInt = price == price.truncateToDouble();
    return isInt ? price.toInt().toString() : price.toStringAsFixed(2);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
