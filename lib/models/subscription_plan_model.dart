// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/models/subscription_plan_model.dart
// Model: Commercial Subscription Plan (Rule 20, Rule 27)
// ============================================================================

class SubscriptionPlanModel {
  final String id;
  final String name;
  final int durationDays;
  final double price;
  final String currency;
  final String? description;
  final int maxRoutersLimit;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.price,
    this.currency = 'SDG',
    this.description,
    this.maxRoutersLimit = 5,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedPrice {
    if (price == price.roundToDouble()) {
      return price.toInt().toString();
    }
    return price.toStringAsFixed(2);
  }

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      durationDays: json['durationDays'] is int
          ? json['durationDays'] as int
          : int.tryParse(json['durationDays']?.toString() ?? '30') ?? 30,
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] as String? ?? 'SDG',
      description: json['description'] as String?,
      maxRoutersLimit: json['maxRoutersLimit'] is int
          ? json['maxRoutersLimit'] as int
          : int.tryParse(json['maxRoutersLimit']?.toString() ?? '5') ?? 5,
      isActive: json['isActive'] is bool
          ? json['isActive'] as bool
          : (json['isActive'] == null || json['isActive']?.toString().toLowerCase() != 'false'),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationDays': durationDays,
      'price': price,
      'currency': currency,
      'description': description,
      'maxRoutersLimit': maxRoutersLimit,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  SubscriptionPlanModel copyWith({
    String? id,
    String? name,
    int? durationDays,
    double? price,
    String? currency,
    String? description,
    int? maxRoutersLimit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      durationDays: durationDays ?? this.durationDays,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      maxRoutersLimit: maxRoutersLimit ?? this.maxRoutersLimit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ManualPaymentMethodModel {
  final String id;
  final String providerName;
  final String accountName;
  final String accountNumber;
  final String? beneficiaryName;
  final String? instructions;
  final String currency;
  final bool isActive;

  const ManualPaymentMethodModel({
    required this.id,
    required this.providerName,
    required this.accountName,
    required this.accountNumber,
    this.beneficiaryName,
    this.instructions,
    this.currency = 'SDG',
    this.isActive = true,
  });

  factory ManualPaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return ManualPaymentMethodModel(
      id: json['id'] as String? ?? '',
      providerName: json['providerName'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      beneficiaryName: json['beneficiaryName'] as String?,
      instructions: json['instructions'] as String?,
      currency: json['currency'] as String? ?? 'SDG',
      isActive: json['isActive'] is bool
          ? json['isActive'] as bool
          : (json['isActive']?.toString().toLowerCase() != 'false'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerName': providerName,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'beneficiaryName': beneficiaryName,
      'instructions': instructions,
      'currency': currency,
      'isActive': isActive,
    };
  }
}

class SubscriptionRequestModel {
  final String id;
  final String status;
  final String planName;
  final double price;
  final String currency;
  final int durationDays;
  final String? senderName;
  final String? referenceNumber;
  final String? receiptUrl;
  final String? paymentMethodName;
  final String? paymentAccountNumber;
  final String? notes;
  final String? reviewNotes;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final String? tenantName;
  final String? tenantSlug;
  final String? requestedBy;

  const SubscriptionRequestModel({
    required this.id,
    required this.status,
    required this.planName,
    required this.price,
    required this.currency,
    required this.durationDays,
    this.senderName,
    this.referenceNumber,
    this.receiptUrl,
    this.paymentMethodName,
    this.paymentAccountNumber,
    this.notes,
    this.reviewNotes,
    this.reviewedAt,
    required this.createdAt,
    this.tenantName,
    this.tenantSlug,
    this.requestedBy,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  String get statusArabic {
    switch (status) {
      case 'APPROVED':
        return 'معتمد';
      case 'REJECTED':
        return 'مرفوض';
      case 'CANCELLED':
        return 'ملغي';
      case 'PENDING':
      default:
        return 'قيد المراجعة';
    }
  }

  /// Formats price cleanly without trailing .0 (e.g. 50 instead of 50.0)
  String get formattedPrice {
    if (price % 1 == 0) {
      return price.toInt().toString();
    }
    return price.toString();
  }

  factory SubscriptionRequestModel.fromJson(Map<String, dynamic> json) {
    final planData = json['plan'] is Map ? json['plan'] as Map<String, dynamic> : null;
    final planName = planData?['name'] as String? ??
        json['planName'] as String? ??
        'باقة اشتراك';
    final priceRaw = json['priceSnapshot'] ?? json['price'] ?? planData?['price'] ?? 0;
    final price = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse(priceRaw?.toString() ?? '0') ?? 0.0;
    final currency = (json['currencySnapshot'] ?? json['currency'] ?? planData?['currency']) as String? ?? 'USD';
    final durationNum = json['durationDaysSnapshot'] ?? json['durationDays'] ?? planData?['durationDays'];
    final durationDays = durationNum is int
        ? durationNum
        : int.tryParse(durationNum?.toString() ?? '30') ?? 30;

    final pmData = json['paymentMethod'] is Map ? json['paymentMethod'] as Map<String, dynamic> : null;
    final pmName = (json['paymentMethod'] is String ? json['paymentMethod'] as String : null) ??
        pmData?['providerName'] as String?;
    final pmAcc = pmData?['accountNumber'] as String?;

    final reqByUser = json['requestedBy'] is Map ? json['requestedBy'] as Map<String, dynamic> : null;
    final userDisplay = reqByUser?['fullName'] ?? reqByUser?['username'] ?? json['requestedBy']?.toString();

    return SubscriptionRequestModel(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      planName: planName,
      price: price,
      currency: currency,
      durationDays: durationDays,
      senderName: json['senderName'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      paymentMethodName: pmName,
      paymentAccountNumber: pmAcc,
      notes: json['notes'] as String?,
      reviewNotes: json['reviewNotes'] as String?,
      reviewedAt: json['reviewedAt'] != null ? DateTime.tryParse(json['reviewedAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      tenantName: json['tenantName'] as String?,
      tenantSlug: json['tenantSlug'] as String?,
      requestedBy: userDisplay,
    );
  }
}
