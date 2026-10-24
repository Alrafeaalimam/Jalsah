// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/card_batch_model.dart
// Model: Card Batch Representation adhering to Backend Schema
// ============================================================================

class CardBatchModel {
  final String id;
  final String batchNumber;
  final String? name;
  final int quantity;
  final String packageId;
  final String? routerId;
  final String? prefix;
  final double unitPrice;
  final double totalPrice;
  final DateTime? createdAt;

  const CardBatchModel({
    required this.id,
    required this.batchNumber,
    this.name,
    required this.quantity,
    required this.packageId,
    this.routerId,
    this.prefix,
    this.unitPrice = 0.0,
    this.totalPrice = 0.0,
    this.createdAt,
  });

  factory CardBatchModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return CardBatchModel(
      id: json['id'] as String? ?? '',
      batchNumber: json['batchNumber'] as String? ?? '',
      name: json['name'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      packageId: json['packageId'] as String? ?? '',
      routerId: json['routerId'] as String?,
      prefix: json['prefix'] as String?,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batchNumber': batchNumber,
      if (name != null) 'name': name,
      'quantity': quantity,
      'packageId': packageId,
      if (routerId != null) 'routerId': routerId,
      if (prefix != null) 'prefix': prefix,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  String get formattedTotalPrice {
    final isInt = totalPrice == totalPrice.truncateToDouble();
    return isInt ? totalPrice.toInt().toString() : totalPrice.toStringAsFixed(2);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardBatchModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
