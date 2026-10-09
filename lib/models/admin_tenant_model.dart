// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/admin_tenant_model.dart
// Model: Admin Tenant View Entity for Super Admin (Rule 19, Rule 26)
// ============================================================================

class AdminTenantModel {
  final String id;
  final String name;
  final String slug;
  final String? contactEmail;
  final String? contactPhone;
  final String currency;
  final String status;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndsAt;
  final String? planName;
  final int maxRoutersLimit;
  final int usersCount;
  final int routersCount;
  final DateTime createdAt;

  const AdminTenantModel({
    required this.id,
    required this.name,
    required this.slug,
    this.contactEmail,
    this.contactPhone,
    required this.currency,
    required this.status,
    required this.subscriptionStatus,
    this.trialEndsAt,
    this.subscriptionEndsAt,
    this.planName,
    required this.maxRoutersLimit,
    required this.usersCount,
    required this.routersCount,
    required this.createdAt,
  });

  bool get isTrial => subscriptionStatus.toUpperCase() == 'TRIAL';
  bool get isActive => subscriptionStatus.toUpperCase() == 'ACTIVE';
  bool get isExpired => subscriptionStatus.toUpperCase() == 'EXPIRED';
  bool get isSuspended => subscriptionStatus.toUpperCase() == 'SUSPENDED';

  factory AdminTenantModel.fromJson(Map<String, dynamic> json) {
    return AdminTenantModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      currency: json['currency'] as String? ?? 'SDG',
      status: (json['status'] as String? ?? 'ACTIVE').toUpperCase(),
      subscriptionStatus:
          (json['subscriptionStatus'] as String? ?? 'TRIAL').toUpperCase(),
      trialEndsAt: json['trialEndsAt'] != null
          ? DateTime.tryParse(json['trialEndsAt'].toString())
          : null,
      subscriptionEndsAt: json['subscriptionEndsAt'] != null
          ? DateTime.tryParse(json['subscriptionEndsAt'].toString())
          : null,
      planName: json['planName'] as String?,
      maxRoutersLimit: (json['maxRoutersLimit'] as num?)?.toInt() ?? 5,
      usersCount: (json['usersCount'] as num?)?.toInt() ?? 0,
      routersCount: (json['routersCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
