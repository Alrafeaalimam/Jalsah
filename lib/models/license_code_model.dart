// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/license_code_model.dart
// Model: License Code Entity (Rule 19, Rule 26, Rule 27)
// ============================================================================

class LicenseCodeModel {
  final String id;
  final String code;
  final String planName;
  final int durationDays;
  final int maxRoutersLimit;
  final String status;
  final String createdByUserId;
  final String? usedByTenantId;
  final String? usedByTenantName;
  final String? usedByTenantSlug;
  final DateTime? usedAt;
  final DateTime createdAt;

  const LicenseCodeModel({
    required this.id,
    required this.code,
    required this.planName,
    required this.durationDays,
    required this.maxRoutersLimit,
    required this.status,
    required this.createdByUserId,
    this.usedByTenantId,
    this.usedByTenantName,
    this.usedByTenantSlug,
    this.usedAt,
    required this.createdAt,
  });

  bool get isUnused => status.toUpperCase() == 'UNUSED';
  bool get isUsed => status.toUpperCase() == 'USED';
  bool get isRevoked => status.toUpperCase() == 'REVOKED';

  factory LicenseCodeModel.fromJson(Map<String, dynamic> json) {
    return LicenseCodeModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      planName: json['planName'] as String? ?? 'خطة قياسية',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      maxRoutersLimit: (json['maxRoutersLimit'] as num?)?.toInt() ?? 5,
      status: (json['status'] as String? ?? 'UNUSED').toUpperCase(),
      createdByUserId: json['createdByUserId'] as String? ?? '',
      usedByTenantId: json['usedByTenantId'] as String?,
      usedByTenantName: json['usedByTenantName'] as String?,
      usedByTenantSlug: json['usedByTenantSlug'] as String?,
      usedAt: json['usedAt'] != null
          ? DateTime.tryParse(json['usedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'planName': planName,
      'durationDays': durationDays,
      'maxRoutersLimit': maxRoutersLimit,
      'status': status,
      'createdByUserId': createdByUserId,
      if (usedByTenantId != null) 'usedByTenantId': usedByTenantId,
      if (usedByTenantName != null) 'usedByTenantName': usedByTenantName,
      if (usedByTenantSlug != null) 'usedByTenantSlug': usedByTenantSlug,
      if (usedAt != null) 'usedAt': usedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
