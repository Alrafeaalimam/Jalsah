// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/platform_settings_model.dart
// Model: Dynamic Platform Settings (Singleton)
// ============================================================================

class PlatformSettingsModel {
  final String id;
  final String supportEmail;
  final List<String> whatsappNumbers;
  final String? primaryColorHex;
  final String? accentColorHex;
  final String appName;
  final DateTime? updatedAt;

  const PlatformSettingsModel({
    required this.id,
    required this.supportEmail,
    required this.whatsappNumbers,
    this.primaryColorHex,
    this.accentColorHex,
    required this.appName,
    this.updatedAt,
  });

  factory PlatformSettingsModel.defaultSettings() {
    return const PlatformSettingsModel(
      id: 'default-platform-settings',
      supportEmail: 'jalsahnetwork@gmail.com',
      whatsappNumbers: ['0115715672', '0115715651'],
      primaryColorHex: '#3B2FA0',
      accentColorHex: '#F5C94B',
      appName: 'جلسة',
    );
  }

  factory PlatformSettingsModel.fromJson(Map<String, dynamic> json) {
    List<String> parseNumbers(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      return ['0115715672', '0115715651'];
    }

    final nums = parseNumbers(json['whatsappNumbers']);

    return PlatformSettingsModel(
      id: json['id']?.toString() ?? 'default-platform-settings',
      supportEmail: json['supportEmail']?.toString() ?? 'jalsahnetwork@gmail.com',
      whatsappNumbers: nums.isNotEmpty ? nums : ['0115715672', '0115715651'],
      primaryColorHex: json['primaryColorHex']?.toString(),
      accentColorHex: json['accentColorHex']?.toString(),
      appName: json['appName']?.toString() ?? 'جلسة',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supportEmail': supportEmail,
      'whatsappNumbers': whatsappNumbers,
      'primaryColorHex': primaryColorHex,
      'accentColorHex': accentColorHex,
      'appName': appName,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  PlatformSettingsModel copyWith({
    String? id,
    String? supportEmail,
    List<String>? whatsappNumbers,
    String? primaryColorHex,
    String? accentColorHex,
    String? appName,
    DateTime? updatedAt,
  }) {
    return PlatformSettingsModel(
      id: id ?? this.id,
      supportEmail: supportEmail ?? this.supportEmail,
      whatsappNumbers: whatsappNumbers ?? this.whatsappNumbers,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      appName: appName ?? this.appName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
