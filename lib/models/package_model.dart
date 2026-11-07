// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/package_model.dart
// Model: Internet Package Representation adhering to Backend Schema
// ============================================================================

class PackageModel {
  final String id;
  final String name;
  final String code;
  final String downloadSpeedLimit;
  final String uploadSpeedLimit;
  final int durationMinutes;
  final int validityDays;
  final int? dataLimitBytes;
  final double price;
  final String hotspotProfileName;
  final bool isActive;
  final String currency;
  final int simultaneousSessions;

  const PackageModel({
    required this.id,
    required this.name,
    required this.code,
    required this.downloadSpeedLimit,
    required this.uploadSpeedLimit,
    required this.durationMinutes,
    required this.validityDays,
    this.dataLimitBytes,
    required this.price,
    required this.hotspotProfileName,
    this.isActive = true,
    this.currency = 'SDG',
    this.simultaneousSessions = 1,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      downloadSpeedLimit: json['downloadSpeedLimit'] as String? ?? '',
      uploadSpeedLimit: json['uploadSpeedLimit'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      validityDays: (json['validityDays'] as num?)?.toInt() ?? 0,
      dataLimitBytes: (json['dataLimitBytes'] as num?)?.toInt(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      hotspotProfileName: json['hotspotProfileName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      currency: json['currency'] as String? ?? 'SDG',
      simultaneousSessions:
          (json['simultaneousSessions'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'downloadSpeedLimit': downloadSpeedLimit,
      'uploadSpeedLimit': uploadSpeedLimit,
      'durationMinutes': durationMinutes,
      'validityDays': validityDays,
      if (dataLimitBytes != null) 'dataLimitBytes': dataLimitBytes,
      'price': price,
      'hotspotProfileName': hotspotProfileName,
      'isActive': isActive,
      'currency': currency,
      'simultaneousSessions': simultaneousSessions,
    };
  }

  String get formattedPrice {
    final isInt = price == price.truncateToDouble();
    final displayPrice = isInt ? price.toInt().toString() : price.toStringAsFixed(2);
    return '$displayPrice $currency';
  }

  String get formattedSpeed => '$downloadSpeedLimit / $uploadSpeedLimit';

  /// Generates the deterministic automatic profile name purely from settings:
  /// `jalsah-d{download}-u{upload}-s{shared}`
  /// Lowercase latin letters, digits, and hyphens only.
  String get automaticProfileName {
    final dl = downloadSpeedLimit.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final ul = uploadSpeedLimit.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final shared = simultaneousSessions > 0 ? simultaneousSessions : 1;
    return 'jalsah-d$dl-u$ul-s$shared';
  }

  /// Generates the canonical profile name from standalone settings.
  static String generateProfileName({
    required String downloadSpeed,
    required String uploadSpeed,
    int simultaneousSessions = 1,
  }) {
    final dl = downloadSpeed.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final ul = uploadSpeed.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final shared = simultaneousSessions > 0 ? simultaneousSessions : 1;
    return 'jalsah-d$dl-u$ul-s$shared';
  }

  /// Validates whether speeds are sufficiently defined for auto-profile creation.
  String? validateAutoProfileSpeeds() {
    if (downloadSpeedLimit.trim().isEmpty) {
      return 'الباقة غير مكتملة: سرعة التحميل (Download) غير محددة.';
    }
    if (uploadSpeedLimit.trim().isEmpty) {
      return 'الباقة غير مكتملة: سرعة الرفع (Upload) غير محددة. يرجى تعديل الباقة وإدخال سرعة الرفع لتمكين الإعداد التلقائي.';
    }
    return null;
  }

  /// معايير تحويل وحدات البيانات الثنائية:
  /// 1GB = 1073741824 بايت (1024 * 1024 * 1024)
  /// 1MB = 1048576 بايت (1024 * 1024)
  static const int bytesPerMb = 1048576;
  static const int bytesPerGb = 1073741824;

  String get formattedDuration {
    if (durationMinutes >= 1440 && durationMinutes % 1440 == 0) {
      final days = durationMinutes ~/ 1440;
      return '$days ${days == 1 ? "يوم" : "أيام"}';
    } else if (durationMinutes >= 60 && durationMinutes % 60 == 0) {
      final hours = durationMinutes ~/ 60;
      return '$hours ${hours == 1 ? "ساعة" : "ساعات"}';
    }
    return '$durationMinutes دقيقة';
  }

  /// التنسيق النصي لحد البيانات (مثال: "5 GB"، "500 MB"، أو "غير محدود" إذا لم يُحدد أو كان 0)
  String get formattedDataLimit {
    if (dataLimitBytes == null || dataLimitBytes! <= 0) {
      return 'غير محدود';
    }
    final bytes = dataLimitBytes!;
    if (bytes >= bytesPerGb) {
      if (bytes % bytesPerGb == 0) {
        return '${bytes ~/ bytesPerGb} GB';
      } else {
        final gb = bytes / bytesPerGb;
        final formatted = gb.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        return '$formatted GB';
      }
    } else if (bytes >= bytesPerMb) {
      if (bytes % bytesPerMb == 0) {
        return '${bytes ~/ bytesPerMb} MB';
      } else {
        final mb = bytes / bytesPerMb;
        final formatted = mb.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        return '$formatted MB';
      }
    }
    return '$bytes B';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackageModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
