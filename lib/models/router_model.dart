// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/router_model.dart
// Model: Router Representation adhering to Backend Schema
// ============================================================================

class RouterModel {
  final String id;
  final String name;
  final String host;
  final int apiPort;
  final String connectionMethod;
  final String status;
  final String? boardModel;
  final String? routerOsVersion;
  final int? cpuLoadPercentage;
  final int? uptimeSeconds;
  final String? lastErrorMessage;
  final DateTime? lastSeenAt;

  const RouterModel({
    required this.id,
    required this.name,
    required this.host,
    required this.apiPort,
    this.connectionMethod = 'ROUTEROS_API_SSL',
    required this.status,
    this.boardModel,
    this.routerOsVersion,
    this.cpuLoadPercentage,
    this.uptimeSeconds,
    this.lastErrorMessage,
    this.lastSeenAt,
  });

  bool get isOnline => status.toUpperCase() == 'ONLINE';

  RouterModel copyWith({
    String? id,
    String? name,
    String? host,
    int? apiPort,
    String? connectionMethod,
    String? status,
    String? boardModel,
    String? routerOsVersion,
    int? cpuLoadPercentage,
    int? uptimeSeconds,
    String? lastErrorMessage,
    DateTime? lastSeenAt,
  }) {
    return RouterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      apiPort: apiPort ?? this.apiPort,
      connectionMethod: connectionMethod ?? this.connectionMethod,
      status: status ?? this.status,
      boardModel: boardModel ?? this.boardModel,
      routerOsVersion: routerOsVersion ?? this.routerOsVersion,
      cpuLoadPercentage: cpuLoadPercentage ?? this.cpuLoadPercentage,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  factory RouterModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return RouterModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      apiPort: (json['apiPort'] as num?)?.toInt() ?? 8728,
      connectionMethod: json['connectionMethod'] as String? ?? 'ROUTEROS_API_SSL',
      status: json['status'] as String? ?? 'OFFLINE',
      boardModel: json['boardModel'] as String?,
      routerOsVersion: json['routerOsVersion'] as String?,
      cpuLoadPercentage: (json['cpuLoadPercentage'] as num?)?.toInt(),
      uptimeSeconds: (json['uptimeSeconds'] as num?)?.toInt(),
      lastErrorMessage: json['lastErrorMessage'] as String?,
      lastSeenAt: parseDate(json['lastSeenAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'apiPort': apiPort,
      'connectionMethod': connectionMethod,
      'status': status,
      if (boardModel != null) 'boardModel': boardModel,
      if (routerOsVersion != null) 'routerOsVersion': routerOsVersion,
      if (cpuLoadPercentage != null) 'cpuLoadPercentage': cpuLoadPercentage,
      if (uptimeSeconds != null) 'uptimeSeconds': uptimeSeconds,
      if (lastErrorMessage != null) 'lastErrorMessage': lastErrorMessage,
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouterModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
