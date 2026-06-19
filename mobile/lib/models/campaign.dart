import 'package:flutter/material.dart';

/// Meta/Facebook campaign as exposed by the CRM Campaigns API.
class Campaign {
  final int id;
  final String? campaignId; // external Meta campaign id
  final String? campaignName;
  final String? campaignStatus;
  final String? dateRange;
  final DateTime? dateStart;
  final DateTime? dateStop;
  final DateTime? lastUpdated;
  final Map<String, dynamic>? statistics;
  final String? facebookAccountName;

  const Campaign({
    required this.id,
    this.campaignId,
    this.campaignName,
    this.campaignStatus,
    this.dateRange,
    this.dateStart,
    this.dateStop,
    this.lastUpdated,
    this.statistics,
    this.facebookAccountName,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return Campaign(
      id: (json['id'] as num).toInt(),
      campaignId: json['campaign_id']?.toString(),
      campaignName: json['campaign_name'] as String?,
      campaignStatus: json['campaign_status'] as String?,
      dateRange: json['date_range'] as String?,
      dateStart: parse(json['date_start']),
      dateStop: parse(json['date_stop']),
      lastUpdated: parse(json['last_updated']),
      statistics: json['statistics'] is Map
          ? Map<String, dynamic>.from(json['statistics'] as Map)
          : null,
      facebookAccountName:
          (json['facebook_account'] is Map &&
                  json['facebook_account']['name'] is String)
              ? json['facebook_account']['name'] as String
              : null,
    );
  }

  /// Status color used by the campaigns list.
  Color get statusColor {
    switch (campaignStatus?.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF22C55E); // green
      case 'PAUSED':
        return const Color(0xFFF59E0B); // amber
      case 'DELETED':
      case 'ARCHIVED':
        return const Color(0xFF94A3B8); // gray
      case 'CAMPAIGN_PAUSED':
        return const Color(0xFFF97316); // orange
      default:
        return const Color(0xFF64748B); // slate
    }
  }

  /// Pull a numeric stat from the `statistics` JSON object safely.
  double statValue(String key) {
    final raw = statistics?[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }

  double get spend => statValue('spend');
  double get impressions => statValue('impressions');
  double get clicks => statValue('clicks');
  double get ctr {
    final imp = impressions;
    if (imp <= 0) return 0;
    return (clicks / imp) * 100;
  }
}
