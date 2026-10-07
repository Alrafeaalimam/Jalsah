// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/models/subscription_status_model.dart
// Model: Tenant Subscription and Licensing Status (Rule 19, Rule 27)
// ============================================================================

class SubscriptionStatusModel {
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final int daysRemaining;
  final String? planName;
  final int currentRoutersCount;
  final int maxRoutersLimit;

  const SubscriptionStatusModel({
    required this.subscriptionStatus,
    this.trialEndsAt,
    required this.daysRemaining,
    this.planName,
    required this.currentRoutersCount,
    required this.maxRoutersLimit,
  });

  bool get isTrial => subscriptionStatus.toUpperCase() == 'TRIAL';
  bool get isActive => subscriptionStatus.toUpperCase() == 'ACTIVE';
  bool get isExpired => subscriptionStatus.toUpperCase() == 'EXPIRED';
  bool get isSuspended => subscriptionStatus.toUpperCase() == 'SUSPENDED';

  /// Whether the tenant is blocked from using system features.
  bool get isBlocked => isExpired || isSuspended;

  factory SubscriptionStatusModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedTrialEndsAt;
    if (json['trialEndsAt'] != null) {
      parsedTrialEndsAt = DateTime.tryParse(json['trialEndsAt'].toString());
    }

    return SubscriptionStatusModel(
      subscriptionStatus:
          (json['subscriptionStatus'] as String? ?? 'TRIAL').toUpperCase(),
      trialEndsAt: parsedTrialEndsAt,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      planName: json['planName'] as String?,
      currentRoutersCount: (json['currentRoutersCount'] as num?)?.toInt() ?? 0,
      maxRoutersLimit: (json['maxRoutersLimit'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscriptionStatus': subscriptionStatus,
      if (trialEndsAt != null) 'trialEndsAt': trialEndsAt!.toIso8601String(),
      'daysRemaining': daysRemaining,
      if (planName != null) 'planName': planName,
      'currentRoutersCount': currentRoutersCount,
      'maxRoutersLimit': maxRoutersLimit,
    };
  }
}
