import 'package:flutter/material.dart';

/// Design job — design work produced by the agency (AI or human designer).
class DesignJob {
  final int id;
  final int? leadId;
  final String? type; // 'ai' | 'human' (whatever the CRM uses)
  final String? status; // 'requested' | 'in_progress' | 'approved' | 'rejected'
  final String? resultUrl;
  final int? designerId;
  final double? price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Optional lead payload returned by the index endpoint (selected fields).
  final String? leadClientName;
  final String? leadPhoneNumber;

  const DesignJob({
    required this.id,
    this.leadId,
    this.type,
    this.status,
    this.resultUrl,
    this.designerId,
    this.price,
    this.createdAt,
    this.updatedAt,
    this.leadClientName,
    this.leadPhoneNumber,
  });

  factory DesignJob.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lead = json['lead'];
    return DesignJob(
      id: (json['id'] as num).toInt(),
      leadId: json['lead_id'] is num ? (json['lead_id'] as num).toInt() : null,
      type: json['type'] as String?,
      status: json['status'] as String?,
      resultUrl: json['result_url'] as String?,
      designerId:
          json['designer_id'] is num ? (json['designer_id'] as num).toInt() : null,
      price: parseDouble(json['price']),
      createdAt: parse(json['created_at']),
      updatedAt: parse(json['updated_at']),
      leadClientName: lead is Map ? lead['client_name'] as String? : null,
      leadPhoneNumber: lead is Map ? lead['phone_number'] as String? : null,
    );
  }

  Color get statusColor {
    switch (status) {
      case 'requested':
        return const Color(0xFF3B82F6); // blue
      case 'in_progress':
        return const Color(0xFFF59E0B); // amber
      case 'approved':
        return const Color(0xFF22C55E); // green
      case 'rejected':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFF94A3B8); // gray
    }
  }

  String get statusLabel {
    switch (status) {
      case 'requested':
        return 'Requested';
      case 'in_progress':
        return 'In progress';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status ?? 'Unknown';
    }
  }

  bool get isAi => type == 'ai';
  bool get isHuman => type == 'human';
  bool get isPending => status == 'requested' || status == 'in_progress';
}
