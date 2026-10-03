// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/sale_model.dart
// Model: Sale Transaction Model adhering to Backend Sale Entity & DTO
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SaleModel {
  final String id;
  final double totalAmount;
  final String paymentMethod;
  final DateTime createdAt;
  final String? soldByName;
  final int cardsCount;
  final String? soldById;

  const SaleModel({
    required this.id,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    this.soldByName,
    this.cardsCount = 1,
    this.soldById,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final itemsRaw = json['items'] as List<dynamic>?;
    final int count = itemsRaw != null && itemsRaw.isNotEmpty
        ? itemsRaw.length
        : (json['cardsCount'] as num?)?.toInt() ?? 1;

    String? parseSoldByName() {
      if (json['soldByName'] is String && (json['soldByName'] as String).isNotEmpty) {
        return json['soldByName'] as String;
      }
      if (json['soldBy'] is Map<String, dynamic>) {
        final soldBy = json['soldBy'] as Map<String, dynamic>;
        return soldBy['name'] as String? ?? soldBy['username'] as String?;
      }
      return null;
    }

    return SaleModel(
      id: json['id'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      createdAt: parseDate(json['createdAt']),
      soldByName: parseSoldByName(),
      cardsCount: count,
      soldById: json['soldById'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      if (soldByName != null) 'soldByName': soldByName,
      'cardsCount': cardsCount,
      if (soldById != null) 'soldById': soldById,
    };
  }

  /// Arabic display label for the payment method
  String get paymentMethodArabic {
    switch (paymentMethod.toUpperCase()) {
      case 'CASH':
        return 'نقدي';
      case 'BANK_TRANSFER':
        return 'تحويل بنكي';
      case 'MOBILE_MONEY':
        return 'محفظة إلكترونية';
      default:
        return paymentMethod;
    }
  }

  /// Icon representing payment method
  IconData get paymentMethodIcon {
    switch (paymentMethod.toUpperCase()) {
      case 'CASH':
        return Icons.payments_rounded;
      case 'BANK_TRANSFER':
        return Icons.account_balance_rounded;
      case 'MOBILE_MONEY':
        return Icons.phone_android_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  /// Accent color for payment method badge
  Color get paymentMethodColor {
    switch (paymentMethod.toUpperCase()) {
      case 'CASH':
        return AppColors.statusOnline; // Green
      case 'BANK_TRANSFER':
        return const Color(0xFF3B82F6); // Blue
      case 'MOBILE_MONEY':
        return const Color(0xFFF59E0B); // Amber
      default:
        return AppColors.heroGradientStart;
    }
  }

  /// Formatted total amount with currency in Sudanese Pounds
  String get formattedTotalAmount {
    final isInt = totalAmount == totalAmount.truncateToDouble();
    final numStr = isInt
        ? totalAmount.toInt().toString()
        : totalAmount.toStringAsFixed(2);
    final formatted = numStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted جنيه سوداني';
  }

  /// Formatted creation date string (YYYY/MM/DD - HH:mm)
  String get formattedDate {
    final y = createdAt.year.toString();
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    final h = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d - $h:$min';
  }

  /// Cards count label in Arabic
  String get cardsCountArabic {
    if (cardsCount == 1) return 'كرت واحد';
    if (cardsCount == 2) return 'كرتان';
    if (cardsCount >= 3 && cardsCount <= 10) return '$cardsCount كروت';
    return '$cardsCount كرت';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
