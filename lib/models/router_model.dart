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
  final String status;
  final String? boardModel;
  final String? routerOsVersion;

  const RouterModel({
    required this.id,
    required this.name,
    required this.host,
    required this.apiPort,
    required this.status,
    this.boardModel,
    this.routerOsVersion,
  });

  bool get isOnline => status.toUpperCase() == 'ONLINE';

  factory RouterModel.fromJson(Map<String, dynamic> json) {
    return RouterModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      apiPort: (json['apiPort'] as num?)?.toInt() ?? 8728,
      status: json['status'] as String? ?? 'OFFLINE',
      boardModel: json['boardModel'] as String?,
      routerOsVersion: json['routerOsVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'apiPort': apiPort,
      'status': status,
      if (boardModel != null) 'boardModel': boardModel,
      if (routerOsVersion != null) 'routerOsVersion': routerOsVersion,
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
