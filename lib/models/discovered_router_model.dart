// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/models/discovered_router_model.dart
// Model: Discovered Router Specification & Diagnostics
// ============================================================================

class DiscoveredRouterModel {
  final String host;
  final int port;
  final bool isMikrotik;
  final String? identity;
  final String? boardName;
  final String? version;
  final String? cpu;
  final String? uptime;
  final String? platform;
  final bool managementReachable;
  final bool authRequired;
  final String? errorMessage;
  final bool isMock;

  const DiscoveredRouterModel({
    required this.host,
    this.port = 80,
    required this.isMikrotik,
    this.identity,
    this.boardName,
    this.version,
    this.cpu,
    this.uptime,
    this.platform,
    this.managementReachable = false,
    this.authRequired = false,
    this.errorMessage,
    this.isMock = false,
  });

  DiscoveredRouterModel copyWith({
    String? host,
    int? port,
    bool? isMikrotik,
    String? identity,
    String? boardName,
    String? version,
    String? cpu,
    String? uptime,
    String? platform,
    bool? managementReachable,
    bool? authRequired,
    String? errorMessage,
    bool? isMock,
  }) {
    return DiscoveredRouterModel(
      host: host ?? this.host,
      port: port ?? this.port,
      isMikrotik: isMikrotik ?? this.isMikrotik,
      identity: identity ?? this.identity,
      boardName: boardName ?? this.boardName,
      version: version ?? this.version,
      cpu: cpu ?? this.cpu,
      uptime: uptime ?? this.uptime,
      platform: platform ?? this.platform,
      managementReachable: managementReachable ?? this.managementReachable,
      authRequired: authRequired ?? this.authRequired,
      errorMessage: errorMessage ?? this.errorMessage,
      isMock: isMock ?? this.isMock,
    );
  }

  String get displayName => identity?.isNotEmpty == true ? identity! : (boardName?.isNotEmpty == true ? boardName! : host);

  String get displaySpecs {
    final parts = <String>[];
    if (boardName?.isNotEmpty == true) parts.add(boardName!);
    if (version?.isNotEmpty == true) parts.add('v$version');
    if (cpu?.isNotEmpty == true) parts.add('CPU: $cpu');
    return parts.join(' | ');
  }

  factory DiscoveredRouterModel.fromJson(Map<String, dynamic> json) {
    return DiscoveredRouterModel(
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 80,
      isMikrotik: json['isMikrotik'] as bool? ?? false,
      identity: json['identity'] as String?,
      boardName: json['boardName'] as String?,
      version: json['version'] as String?,
      cpu: json['cpu'] as String?,
      uptime: json['uptime'] as String?,
      platform: json['platform'] as String?,
      managementReachable: json['managementReachable'] as bool? ?? false,
      authRequired: json['authRequired'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
      isMock: json['isMock'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'isMikrotik': isMikrotik,
      'identity': identity,
      'boardName': boardName,
      'version': version,
      'cpu': cpu,
      'uptime': uptime,
      'platform': platform,
      'managementReachable': managementReachable,
      'authRequired': authRequired,
      'errorMessage': errorMessage,
      'isMock': isMock,
    };
  }
}
